import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:synca_app/src/core/constants/task_status.dart';
import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/member/view_model/timeline_entry.dart';

/// Builds the member's contribution timeline out of their tasks.
///
/// Same shape as `MyTasksViewModel` — it listens to the very same
/// `streamTasksForUser` query, so the timeline and the task list can never
/// disagree, and Firestore serves both from one snapshot listener.
///
/// ## What is recorded and what is still guessed
///
/// **Recorded** — read from a field `TaskService` writes once and never
/// overwrites, so it stays true no matter what happens to the task afterwards:
///
/// - `createdAt`  → Task created
/// - `claimedAt`  → Task claimed
/// - `completedAt` → Task completed, and only while `status.isDone`
///
/// **Still inferred** — nothing in the data model records these, so
/// `lastUpdatedAt` stands in for them:
///
/// - Started work / Marked ready for review. `lastUpdatedAt` is overwritten by
///   every write, so this is only correct while the status change is the most
///   recent thing that happened to the task. Move a task to In progress and
///   then upload proof, and the "started work" time silently becomes the proof
///   time.
/// - Proof uploaded. `proofUrl` has no timestamp of its own; it is written in
///   the same call as a status change, so that call's time is used.
///
/// The remaining gap is history: a task that went Not started → In progress →
/// Ready for review keeps only the last of those moments, because each write
/// overwrote the one before. Closing that needs an append-only `activity`
/// subcollection written by `TaskService` on every mutation — a data-model
/// change, not something this class can fix.
///
/// ## Unresolved timestamps
///
/// Writes use `FieldValue.serverTimestamp()`, which resolves a beat after the
/// local snapshot fires. Entries whose date is null or still sitting at the
/// Unix epoch are dropped rather than rendered — see [_epochCutoff].
class TimelineViewModel extends ChangeNotifier {
  TimelineViewModel({required this.user, TaskService? taskService})
    : _taskService = taskService ?? TaskService() {
    _subscribe();
  }

  final AppUser user;
  final TaskService _taskService;

  StreamSubscription<List<Task>>? _subscription;

  List<TimelineEntry> _entries = const [];
  bool _isLoading = true;
  String? _errorMessage;

  List<TimelineEntry> get entries => List.unmodifiable(_entries);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isEmpty => !_isLoading && _errorMessage == null && _entries.isEmpty;

  void _subscribe() {
    _subscription = _taskService
        .streamTasksForUser(user.uid)
        .listen(
          (tasks) {
            _entries = _deriveEntries(tasks);
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) {
            _isLoading = false;
            _errorMessage = _describeError(error);
            debugPrint('timeline streamTasksForUser failed: $error');
            debugPrintStack(stackTrace: stackTrace);
            notifyListeners();
          },
        );
  }

  /// Anything at or before this instant is treated as "no date".
  ///
  /// `FieldValue.serverTimestamp()` is a sentinel, not a value. Firestore fires
  /// a local snapshot the moment a write is queued, with the field still
  /// unresolved, and only then does the server's real time arrive in a second
  /// snapshot. For the non-nullable dates, `Task.fromMap` fills that gap with
  /// the Unix epoch — so a task created two seconds ago briefly claims to be
  /// from 1 January 1970.
  ///
  /// Rather than render that, entries at the epoch are dropped and reappear on
  /// the next snapshot with their true time. Ten seconds of slack, because the
  /// exact epoch value depends on how the gap was filled; no real coursework
  /// task is dated 1970, so there is nothing to lose.
  ///
  /// `static final`, not `const`: `DateTime` arithmetic isn't a compile-time
  /// constant, but this only needs computing once for the whole class.
  static final DateTime _epochCutoff = DateTime.fromMillisecondsSinceEpoch(
    0,
  ).add(const Duration(seconds: 10));

  /// Turns the task list into timeline rows, newest first.
  ///
  /// Three of these are now **recorded** — read straight out of a field written
  /// once by `TaskService` — and survive later edits. The rest are still
  /// inferred; see the class note above for why.
  List<TimelineEntry> _deriveEntries(List<Task> tasks) {
    final derived = <TimelineEntry>[];

    for (final task in tasks) {
      // ---- recorded: straight from a stored field ----

      _addEntry(derived, task, TimelineEventType.taskCreated, task.createdAt);

      // Null until somebody claims it, which is exactly when there is no claim
      // to show. No guessing from status any more.
      _addEntry(derived, task, TimelineEventType.taskClaimed, task.claimedAt);

      // ---- the most recent state change ----

      if (task.status.isDone) {
        // `completedAt` is set-only and never cleared, so a task reopened after
        // completion still carries an old date. Gating on `status.isDone` is
        // what stops that stale value showing as a completion that was undone.
        _addEntry(
          derived,
          task,
          TimelineEventType.taskCompleted,
          task.completedAt,
        );
      } else {
        // Still inferred, and unavoidably so: nothing records *when* a task
        // moved to In progress or Ready for review. `lastUpdatedAt` is the
        // closest thing, and it is right whenever the status change was the
        // most recent write — which it normally is.
        //
        // Returns null for notStarted and completed, both of which are already
        // covered by a recorded field above. That is what prevents a duplicate.
        final inFlight = _inFlightEventFor(task.status);
        if (inFlight != null) {
          _addEntry(derived, task, inFlight, task.lastUpdatedAt);
        }
      }

      // ---- proof: real event, borrowed timestamp ----

      // `proofUrl` has no date of its own. It is written in the same call as a
      // status change, so the last write time is accurate in practice.
      if (task.proofUrl != null) {
        _addEntry(
          derived,
          task,
          TimelineEventType.proofUploaded,
          task.lastUpdatedAt,
        );
      }
    }

    // `sort` mutates the list in place and returns nothing — a common trip-up.
    // `derived..sort(...)` uses the cascade operator so the expression still
    // evaluates to the list.
    return derived..sort(TimelineEntry.newestFirst);
  }

  /// Adds one row, unless its date is missing or unresolved.
  ///
  /// Every entry goes through here, so the epoch guard cannot be forgotten at
  /// one of the call sites.
  ///
  /// The null check is a plain `if` rather than being folded into the cutoff
  /// comparison because Dart's flow analysis then *promotes* `at` from
  /// `DateTime?` to `DateTime` for the rest of the method — no `!` needed.
  void _addEntry(
    List<TimelineEntry> into,
    Task task,
    TimelineEventType type,
    DateTime? at,
  ) {
    if (at == null) return;
    if (!at.isAfter(_epochCutoff)) return;

    into.add(
      TimelineEntry(
        type: type,
        timestamp: at,
        taskId: task.id,
        taskTitle: task.title,
      ),
    );
  }

  /// The event implied by a task that is under way, or null when the status is
  /// already covered by a recorded timestamp.
  ///
  /// Listing `notStarted` and `completed` explicitly rather than using `_`
  /// keeps this exhaustive: adding a fifth status becomes a compile error here,
  /// instead of silently falling through to null and losing an event.
  TimelineEventType? _inFlightEventFor(TaskStatus status) => switch (status) {
    TaskStatus.inProgress => TimelineEventType.workStarted,
    TaskStatus.readyForReview => TimelineEventType.readyForReview,
    TaskStatus.notStarted || TaskStatus.completed => null,
  };

  String _describeError(Object error) {
    if (error is FirebaseException) {
      return '[${error.code}]\n\n${error.message ?? error.toString()}';
    }
    return error.toString();
  }

  void retry() {
    _subscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    _subscribe();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
