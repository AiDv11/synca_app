import 'package:synca_app/src/core/services/task_service.dart';

/// The kinds of thing that show up on a contribution timeline.
enum TimelineEventType {
  taskCreated,
  taskClaimed,
  workStarted,
  readyForReview,
  proofUploaded,
  taskCompleted;

  /// What the row says happened.
  String get label => switch (this) {
    TimelineEventType.taskCreated => 'Task created',
    TimelineEventType.taskClaimed => 'Task claimed',
    TimelineEventType.workStarted => 'Started work',
    TimelineEventType.readyForReview => 'Marked ready for review',
    TimelineEventType.proofUploaded => 'Proof uploaded',
    TimelineEventType.taskCompleted => 'Task completed',
  };

  /// Orders events that share a timestamp.
  ///
  /// Uploading proof and flipping the status happen in one Firestore write, so
  /// they carry the *same* `lastUpdatedAt`. Sorting on time alone would let
  /// them swap places between rebuilds — the list would flicker. This makes the
  /// order deterministic, and puts proof below the status change it supports.
  int get sortRank => switch (this) {
    TimelineEventType.proofUploaded => 0,
    _ => 1,
  };
}

/// One row on the timeline: what happened, to which task, and when.
///
/// This is **not** a Firestore document, which is why it lives beside the
/// ViewModel rather than in a `model/` folder — CLAUDE.md reserves "Model" for
/// classes that mirror a stored document, and nothing like this is stored.
/// Every instance is derived at read time from a [Task]'s timestamps.
class TimelineEntry {
  const TimelineEntry({
    required this.type,
    required this.timestamp,
    required this.taskId,
    required this.taskTitle,
  });

  final TimelineEventType type;

  /// When it happened — or the closest the stored data can get. See
  /// `TimelineViewModel` for exactly how much of this is inferred.
  final DateTime timestamp;

  final String taskId;
  final String taskTitle;

  /// Newest first, with [TimelineEventType.sortRank] settling ties.
  ///
  /// A `static` comparator rather than making the class `Comparable`: sorting
  /// newest-first is a decision this screen makes, not an intrinsic property of
  /// an entry, and another screen might want the opposite.
  static int newestFirst(TimelineEntry a, TimelineEntry b) {
    final byTime = b.timestamp.compareTo(a.timestamp);
    if (byTime != 0) return byTime;
    return b.type.sortRank.compareTo(a.type.sortRank);
  }

  @override
  String toString() =>
      'TimelineEntry(${type.name} on $taskTitle at $timestamp)';
}
