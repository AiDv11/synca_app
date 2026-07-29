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

  /// What the member has typed into the search field. Empty means no search.
  String _query = '';

  /// Tasks in the group that nobody owns yet, soonest deadline first.
  ///
  /// **Unsearched.** The list on screen is [visibleTasks]; this is the full set,
  /// and it is what [isEmpty] asks about.
  List<Task> get unclaimedTasks => List.unmodifiable(_unclaimedTasks);

  String get query => _query;

  /// [unclaimedTasks] narrowed by [query], matching title and description.
  ///
  /// In memory, over tasks already streamed. Firestore has no substring search
  /// at all — matching "review" against a title needs either an exact-prefix
  /// range query, which would miss anything not at the start, or a third-party
  /// index like Algolia. Neither is worth it for a group with tens of tasks
  /// that are already on the device.
  ///
  /// Case-insensitive on both sides, so typing `lit` finds "Literature review".
  /// The description is searched as well as the title because a task's title is
  /// often terse — "Section 3" — while the thing the member remembers about it
  /// lives in the description.
  ///
  /// Computed on demand rather than stored: a cached copy would need rebuilding
  /// whenever either the stream or the query changed, and the day one is missed
  /// the sheet shows the wrong rows.
  List<Task> get visibleTasks {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return unclaimedTasks;

    return List.unmodifiable(
      _unclaimedTasks.where(
        (task) =>
            task.title.toLowerCase().contains(needle) ||
            task.description.toLowerCase().contains(needle),
      ),
    );
  }

  /// Updates the search. No Firestore call — this narrows what is already held.
  ///
  /// No debouncing, deliberately. Debouncing exists to avoid hammering a
  /// network or re-running expensive work per keystroke; this is one pass over
  /// a handful of objects already in memory, and a delay would only make the
  /// list feel like it was lagging behind the typing.
  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

  bool get isLoading => _isLoading;

  /// True while a claim is in flight. The sheet uses it to disable the list, so
  /// an impatient double-tap can't fire two claims at once.
  bool get isClaiming => _isClaiming;

  String? get errorMessage => _errorMessage;

  /// The member hasn't been put in a group yet — a different empty state from
  /// "the group has no spare tasks", and it needs different wording.
  bool get hasNoGroup => !user.hasGroup;

  /// The group has no spare work at all.
  ///
  /// Deliberately about [unclaimedTasks], not [visibleTasks]: this is "there is
  /// nothing to claim", which is a different message from "your search found
  /// nothing". See [hasNoMatches].
  bool get isEmpty =>
      !_isLoading && _errorMessage == null && _unclaimedTasks.isEmpty;

  /// There is unclaimed work, but the search does not match any of it.
  ///
  /// Split from [isEmpty] so the two can say different things. Told apart, one
  /// says the group has nothing spare and the other says to try different
  /// words; merged, whichever wording won would be wrong half the time — and
  /// the wrong one here would have a member believe there is no work left when
  /// they have simply mistyped.
  bool get hasNoMatches =>
      !_isLoading &&
      _errorMessage == null &&
      _unclaimedTasks.isNotEmpty &&
      visibleTasks.isEmpty;

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
