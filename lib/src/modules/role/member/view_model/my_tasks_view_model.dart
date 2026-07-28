import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:synca_app/src/core/constants/task_status.dart';
import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/member/view_model/load_error_message.dart';

/// State and behaviour for the member's "My Tasks" screen.
///
/// This is the **ViewModel** in MVVM. It sits between the widget and
/// [TaskService]: the widget asks it for data and calls its methods, and it
/// calls the service. The widget never imports `cloud_firestore`.
///
/// It extends [ChangeNotifier], Flutter's built-in "something changed" object.
/// Anything can subscribe to it; calling [notifyListeners] tells every
/// subscriber to rebuild. The screen listens with a `ListenableBuilder`. No
/// state-management package needed — this all ships with Flutter.
///
/// The flow is worth understanding, because it's what makes the screen live:
///
///   Firestore changes → stream emits → this VM updates its fields and calls
///   notifyListeners() → ListenableBuilder rebuilds → the user sees it
///
/// Nobody polls, and nothing calls `setState` manually. A task marked complete
/// on another member's phone shows up here within a second.
class MyTasksViewModel extends ChangeNotifier {
  MyTasksViewModel({required this.user, TaskService? taskService})
    : _taskService = taskService ?? TaskService() {
    _subscribe();
  }

  /// The signed-in member. Public and `final`: the View may read it, and
  /// nothing — inside or out — can swap it for a different person.
  final AppUser user;

  final TaskService _taskService;

  /// The live connection to Firestore. Kept in a field for one reason: it has
  /// to be cancelled in [dispose]. An uncancelled subscription keeps listening
  /// after the screen is gone — it costs Firestore reads forever and will try
  /// to update a widget that no longer exists.
  StreamSubscription<List<Task>>? _subscription;

  List<Task> _tasks = const [];
  bool _isLoading = true;
  String? _errorMessage;

  /// The fields above are private (`_`) and exposed through getters, so the
  /// View can read state but can't reach in and change it. Every change goes
  /// through a method on this class, which is what keeps [notifyListeners]
  /// from being forgotten.
  List<Task> get tasks => List.unmodifiable(_tasks);

  /// True until the very first batch of tasks arrives.
  bool get isLoading => _isLoading;

  /// Set when the stream fails — offline, or Firestore rules refused the read.
  String? get errorMessage => _errorMessage;

  /// Loaded fine, no error, but this member owns nothing yet.
  bool get isEmpty => !_isLoading && _errorMessage == null && _tasks.isEmpty;

  int get totalCount => _tasks.length;

  int get completedCount => _tasks.where((task) => task.status.isDone).length;

  /// Progress as 0.0–1.0, ready for a `LinearProgressIndicator`.
  ///
  /// The zero check isn't defensive padding — `0 / 0` in Dart is `NaN`, and a
  /// progress bar given NaN throws.
  ///
  /// This and the two counts above are *derived* values, computed from the task
  /// list on demand rather than stored in their own fields. Storing them would
  /// mean remembering to recalculate on every change — the classic way for a
  /// "3 of 8" label to drift out of step with the list right below it.
  double get progress => totalCount == 0 ? 0 : completedCount / totalCount;

  /// Opens the live connection and wires incoming tasks into screen state.
  void _subscribe() {
    // A member who hasn't joined a group has nothing to query, and asking
    // anyway would be worse than pointless: the query needs a real groupId to
    // be legal under the Firestore rules, so sending `groupId: ''` would come
    // back `permission-denied` and the screen would show an error instead of
    // the perfectly accurate "no tasks yet".
    //
    // Falling straight to loaded-and-empty puts the existing empty state on
    // screen, which already tells them to claim something.
    if (!user.hasGroup) {
      _tasks = const [];
      _isLoading = false;
      _errorMessage = null;
      // Harmless in the constructor, where nobody is listening yet, and
      // necessary on the retry path, where the screen is waiting to be told
      // the reload finished.
      notifyListeners();
      return;
    }

    _subscription = _taskService
        .streamTasksForUser(uid: user.uid, groupId: user.groupId)
        .listen(
          (tasks) {
            _tasks = tasks;
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          // Errors on a stream arrive through this callback, not as a thrown
          // exception — there is no `try` around a stream that can catch them.
          onError: (Object error, StackTrace stackTrace) {
            _isLoading = false;
            _errorMessage = describeLoadError(error, subject: 'tasks');

            // The screen gets a plain sentence; the console gets the truth.
            // `flutter run` shows the code, the message and the stack trace,
            // none of which belong in front of a student.
            debugPrint('streamTasksForUser failed: $error');
            debugPrintStack(stackTrace: stackTrace);

            notifyListeners();
          },
        );
  }

  /// Drops the failed stream and starts a fresh one, for the Retry button.
  void retry() {
    _subscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    _subscribe();
  }

  /// Moves a task to a new status.
  ///
  /// Returns null on success, or a message to show the user on failure.
  /// Returning the error rather than storing it keeps a transient problem
  /// ("that write failed") separate from screen state ("the list is broken") —
  /// the first belongs in a SnackBar, the second in the body of the page.
  ///
  /// Notice there's no `notifyListeners()` and no local list edit here. The
  /// write goes to Firestore, Firestore pushes the change back down the stream,
  /// and the listener above updates the UI. One source of truth. Editing the
  /// local list too would briefly show a value the database hadn't accepted.
  /// [proofUrl] is optional and is passed straight through. Null means "leave
  /// any proof already on the task alone" — `updateStatus` drops the field from
  /// the write rather than overwriting it with nothing.
  Future<String?> changeStatus(
    Task task,
    TaskStatus status, {
    String? proofUrl,
  }) async {
    // Nothing to do, and this avoids a pointless write to Firestore.
    //
    // The proof check matters: the member may have opened the sheet purely to
    // attach a link without moving the status, and skipping on status alone
    // would silently throw that link away.
    if (task.status == status && proofUrl == null) return null;

    try {
      await _taskService.updateStatus(
        taskId: task.id,
        status: status,
        proofUrl: proofUrl,
      );
      return null;
    } on FirebaseException catch (e) {
      return e.code == 'permission-denied'
          ? "You don't have permission to change that task."
          : "Couldn't update the task. Please try again.";
    } catch (_) {
      return "Couldn't update the task. Please try again.";
    }
  }

  /// `dispose` is the counterpart to the constructor — the screen calls it when
  /// it is removed. Cancelling here is what stops the leak described above.
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
