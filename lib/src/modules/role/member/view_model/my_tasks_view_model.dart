import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:synca_app/src/core/constants/task_status.dart';
import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/member/model/services/task_ownership_service.dart';
import 'package:synca_app/src/modules/role/member/model/services/task_proof_service.dart';
import 'package:synca_app/src/modules/role/member/view_model/load_error_message.dart';
import 'package:synca_app/src/modules/role/member/view_model/task_filter.dart';

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
  MyTasksViewModel({
    required this.user,
    TaskService? taskService,
    TaskOwnershipService? ownershipService,
    TaskProofService? proofService,
  }) : _taskService = taskService ?? TaskService(),
       _ownershipService = ownershipService ?? TaskOwnershipService(),
       _proofService = proofService ?? TaskProofService() {
    _subscribe();
  }

  /// The signed-in member. Public and `final`: the View may read it, and
  /// nothing — inside or out — can swap it for a different person.
  final AppUser user;

  final TaskService _taskService;
  final TaskOwnershipService _ownershipService;
  final TaskProofService _proofService;

  /// The live connection to Firestore. Kept in a field for one reason: it has
  /// to be cancelled in [dispose]. An uncancelled subscription keeps listening
  /// after the screen is gone — it costs Firestore reads forever and will try
  /// to update a widget that no longer exists.
  StreamSubscription<List<Task>>? _subscription;

  List<Task> _tasks = const [];
  bool _isLoading = true;
  String? _errorMessage;

  /// Which chip is selected above the list.
  ///
  /// Held here, not in the widget, and that is what makes it survive: the Tasks
  /// page pushes a task detail route over itself, and state kept in a `State`
  /// object would be fine — but state kept in the ViewModel is also unaffected
  /// by the page being rebuilt for any other reason. Coming back from a detail
  /// page lands on the same filter the member left.
  TaskFilter _filter = TaskFilter.all;

  /// The fields above are private (`_`) and exposed through getters, so the
  /// View can read state but can't reach in and change it. Every change goes
  /// through a method on this class, which is what keeps [notifyListeners]
  /// from being forgotten.
  ///
  /// **Every task the member owns**, unfiltered. The contribution card counts
  /// from this — see [totalCount].
  List<Task> get tasks => List.unmodifiable(_tasks);

  TaskFilter get filter => _filter;

  /// The tasks the list should draw: [tasks] with [filter] applied.
  ///
  /// Computed on demand rather than stored in its own field, for the same
  /// reason the counts below are: a stored copy has to be rebuilt whenever
  /// either the stream or the filter changes, and the day somebody forgets one
  /// of those, the list quietly shows the wrong thing.
  ///
  /// The work is a single pass over a handful of tasks, on a list that only
  /// changes when Firestore pushes or a chip is tapped. There is nothing here
  /// worth caching.
  List<Task> get visibleTasks =>
      List.unmodifiable(_tasks.where(_filter.matches));

  /// Switches the chip. No Firestore call — this filters what is already held.
  void setFilter(TaskFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    notifyListeners();
  }

  /// True until the very first batch of tasks arrives.
  bool get isLoading => _isLoading;

  /// Set when the stream fails — offline, or Firestore rules refused the read.
  String? get errorMessage => _errorMessage;

  /// Loaded fine, no error, but this member owns nothing yet.
  ///
  /// Deliberately about [tasks], not [visibleTasks] — this is "you have not
  /// claimed anything", a different screen from "this filter matches nothing".
  /// See [hasNoMatches].
  bool get isEmpty => !_isLoading && _errorMessage == null && _tasks.isEmpty;

  /// The member owns tasks, but none survive the current filter.
  ///
  /// Split from [isEmpty] so the two can say different things. Apart, one
  /// invites the member to claim work and the other says the pile they picked
  /// is empty; merged, whichever wording won would be wrong half the time.
  bool get hasNoMatches =>
      !_isLoading &&
      _errorMessage == null &&
      _tasks.isNotEmpty &&
      visibleTasks.isEmpty;

  /// One task by id, or null if it is no longer in the member's list.
  ///
  /// This is what lets the detail page stay live without opening a second
  /// Firestore listener. It reads out of the same `_tasks` the stream fills, so
  /// a change made on another device redraws the detail page and the list
  /// together, from one snapshot.
  ///
  /// **Null is a normal answer**, not an error, and the detail page has to
  /// handle it: the task is gone the moment it stops matching "owned by me" —
  /// released, reassigned by the leader, or the member left the group.
  ///
  /// A plain loop rather than `firstWhere`, which throws when nothing matches
  /// and whose `orElse` would need a fake Task to return.
  Task? taskById(String id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  /// The three values below count **all** tasks, never the filtered list.
  ///
  /// The contribution card measures how much of the member's work is done — a
  /// fact about the project, not about what happens to be on screen. A progress
  /// bar that jumped to 100% because somebody tapped "Completed" would be worse
  /// than no progress bar at all.
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

  /// Changes the proof link on a task, or removes it when [proofUrl] is empty.
  ///
  /// Same contract as [changeStatus]: null on success, a sentence to show the
  /// member on failure.
  ///
  /// No status is written, which is the entire point — correcting a mistyped
  /// link should not restate that the work was submitted. Permitted by the
  /// deployed rules with no change: `isOwnerUpdatingOwnTask` allows
  /// `hasOnly(['status', 'proofUrl', 'lastUpdatedAt', 'completedAt'])`, and a
  /// subset of that list passes.
  ///
  /// One method for edit and remove because they are the same write. The
  /// difference is entirely in what the caller must ask first.
  Future<String?> updateProof(Task task, String proofUrl) async {
    // The rules enforce this too; here it just avoids sending a write that is
    // certain to be refused.
    if (task.ownerUid != user.uid) {
      return "That task isn't yours to edit.";
    }

    try {
      await _proofService.setProof(taskId: task.id, proofUrl: proofUrl);
      return null;
    } on FirebaseException catch (e) {
      debugPrint('setProof failed: [${e.code}] ${e.message}');
      return e.code == 'permission-denied'
          ? "You don't have permission to change that task."
          : "Couldn't save the proof link. Please try again.";
    } catch (error) {
      debugPrint('setProof failed: $error');
      return "Couldn't save the proof link. Please try again.";
    }
  }

  /// Gives a task back to the group.
  ///
  /// Same contract as [changeStatus]: null on success, a sentence to show the
  /// member on failure. And the same reason there is no local list edit — the
  /// released task stops matching `ownerUid == me`, so Firestore drops it from
  /// the stream and the row disappears on its own.
  ///
  /// Permitted by the deployed rules through `isOwnerReleasingTask()`, and
  /// confirmed working: the released task reappears in the claim sheet.
  Future<String?> releaseTask(Task task) async {
    // Checked here as well as in the service and the rules. This one is not
    // about security — it is about not sending a write that is certain to be
    // refused, when the list on screen already says the task isn't theirs.
    if (task.ownerUid != user.uid) {
      return "That task isn't yours to release.";
    }

    try {
      await _ownershipService.releaseTask(taskId: task.id, uid: user.uid);
      return null;
    } on StateError catch (e) {
      // Thrown by the service when the document changed underneath — already
      // released, or reassigned by the leader a moment ago. Its message is
      // already written for the member.
      return e.message;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // The rule permits this write, so reaching here means the request no
        // longer fits it — most likely the task moved out of the member's
        // group, or isOwnerReleasingTask and the service disagree about which
        // fields are written.
        debugPrint(
          'releaseTask refused: the write no longer matches '
          'isOwnerReleasingTask in firestore.rules. [${e.code}] ${e.message}',
        );
        return "You don't have permission to release that task.";
      }
      return "Couldn't release the task. Please try again.";
    } catch (error) {
      debugPrint('releaseTask failed: $error');
      return "Couldn't release the task. Please try again.";
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
