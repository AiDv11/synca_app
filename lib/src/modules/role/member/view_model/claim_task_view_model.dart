import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';

/// State and behaviour for the "Claim a Task" sheet.
///
/// A second, smaller ViewModel rather than more methods on
/// `MyTasksViewModel`, because its lifetime is different. This one is created
/// when the sheet opens and disposed when it closes, so the group-wide query
/// only runs while the member is actually looking at it. Folding it into the
/// tasks screen would mean streaming every task in the group for the whole
/// time the app is open — Firestore bills per document read.
class ClaimTaskViewModel extends ChangeNotifier {
  ClaimTaskViewModel({required this.user, TaskService? taskService})
    : _taskService = taskService ?? TaskService() {
    // A user with no group has nothing to query. Subscribing anyway would send
    // Firestore `where('groupId', isEqualTo: '')`, which is a real query that
    // costs a read and always returns nothing.
    if (user.hasGroup) {
      _subscribe();
    } else {
      _isLoading = false;
    }
  }

  /// The signed-in member. Public and `final`: the View may read it, and
  /// nothing can swap it for a different person.
  final AppUser user;

  final TaskService _taskService;

  StreamSubscription<List<Task>>? _subscription;

  List<Task> _unclaimedTasks = const [];
  bool _isLoading = true;
  bool _isClaiming = false;
  String? _errorMessage;

  /// Tasks in the group that nobody owns yet, soonest deadline first.
  List<Task> get unclaimedTasks => List.unmodifiable(_unclaimedTasks);

  bool get isLoading => _isLoading;

  /// True while a claim is in flight. The sheet uses it to disable the list, so
  /// an impatient double-tap can't fire two claims at once.
  bool get isClaiming => _isClaiming;

  String? get errorMessage => _errorMessage;

  /// The member hasn't been put in a group yet — a different empty state from
  /// "the group has no spare tasks", and it needs different wording.
  bool get hasNoGroup => !user.hasGroup;

  bool get isEmpty =>
      !_isLoading && _errorMessage == null && _unclaimedTasks.isEmpty;

  void _subscribe() {
    _subscription = _taskService
        .streamTasksForGroup(user.groupId)
        .listen(
          (tasks) {
            // The service is deliberately role-agnostic and returns every task
            // in the group, so the filtering happens here. Firestore *could*
            // filter this server-side, but that would need another composite
            // index, and a coursework group has tens of tasks, not thousands.
            _unclaimedTasks = tasks.where((task) => !task.isClaimed).toList();
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (Object error) {
            _isLoading = false;
            _errorMessage = "We couldn't load the group's tasks.";
            notifyListeners();
          },
        );
  }

  /// Takes a task for this member.
  ///
  /// Returns null on success, or a message to show on failure.
  ///
  /// The most interesting failure is the race: two members tap the same task at
  /// the same moment. `TaskService.claimTask` runs in a transaction and throws
  /// [StateError] for the loser, with a message already written for a human —
  /// "That task was already claimed by Sara." So we pass `e.message` straight
  /// through instead of inventing our own wording.
  ///
  /// No manual list edit is needed afterwards. The claim writes an `ownerUid`,
  /// Firestore pushes the change back down the stream, the filter above drops
  /// the task, and it disappears from the sheet on its own.
  Future<String?> claim(Task task) async {
    if (_isClaiming) return null;

    _isClaiming = true;
    notifyListeners();

    try {
      await _taskService.claimTask(
        taskId: task.id,
        uid: user.uid,
        name: user.name,
      );
      return null;
    } on StateError catch (e) {
      return e.message;
    } on FirebaseException catch (e) {
      return e.code == 'permission-denied'
          ? "You don't have permission to claim that task."
          : "Couldn't claim the task. Please try again.";
    } catch (_) {
      return "Couldn't claim the task. Please try again.";
    } finally {
      // `finally` runs on success and on failure alike, so the sheet can never
      // get stuck in its disabled state.
      _isClaiming = false;
      _safeNotify();
    }
  }

  /// Notifies only if this object is still alive.
  ///
  /// The claim above has an `await` in it, and the member can swipe the sheet
  /// away while that write is still in flight. That disposes this ViewModel,
  /// and a plain [notifyListeners] on a disposed [ChangeNotifier] throws. This
  /// is the ViewModel version of the `if (!mounted) return` check a widget does
  /// after an await — same problem, same shape of fix.
  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
