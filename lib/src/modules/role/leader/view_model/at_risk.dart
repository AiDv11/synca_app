import 'package:synca_app/src/core/constants/task_status.dart';
import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/core/utils/deadline_format.dart';

/// How the leader dashboard decides a task is falling behind.
///
/// Kept in its own file so the rule lives in one place: the summary card's
/// count, the row highlight, and any later "flagged" filter all call the same
/// function. Two copies of "close" would eventually disagree.
///
/// A task is at-risk when it is not finished and either:
///
/// 1. The deadline is close (within [closeDeadlineDays] days, including today
///    and overdue) **and** the status is still [TaskStatus.notStarted], or
/// 2. Nobody has touched it for [staleDays] days (`lastUpdatedAt` is stale).
///
/// Finished work is never at-risk — there is nothing left to act on.
abstract final class AtRisk {
  /// "Close" means this many whole days out, inclusive. Day 0 is today.
  static const int closeDeadlineDays = 3;

  /// "Stale" means no write for this many whole days.
  static const int staleDays = 7;

  /// True when [task] should be emphasised on the Team Dashboard.
  ///
  /// [now] is injectable so a test can freeze the clock; the UI omits it.
  static bool isAtRisk(Task task, {DateTime? now}) {
    if (task.status.isDone) return false;

    final clock = now ?? DateTime.now();

    final daysLeft = DeadlineFormat.daysUntil(task.deadline, now: clock);
    if (task.status == TaskStatus.notStarted &&
        daysLeft <= closeDeadlineDays) {
      return true;
    }

    final daysSinceUpdate = clock.difference(task.lastUpdatedAt).inDays;
    if (daysSinceUpdate >= staleDays) return true;

    return false;
  }

  /// Short reason shown under the owner name on an at-risk row.
  ///
  /// Prefer the deadline wording when that is why the flag fired; otherwise
  /// say the task has gone quiet. Callers that already know [isAtRisk] is true
  /// still get a useful sentence if both conditions somehow apply.
  static String reason(Task task, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final daysLeft = DeadlineFormat.daysUntil(task.deadline, now: clock);

    if (task.status == TaskStatus.notStarted &&
        daysLeft <= closeDeadlineDays) {
      return DeadlineFormat.relative(
        task.deadline,
        isDone: task.status.isDone,
        now: clock,
      );
    }

    final daysSinceUpdate = clock.difference(task.lastUpdatedAt).inDays;
    if (daysSinceUpdate <= 0) return 'No recent activity';
    if (daysSinceUpdate == 1) return 'No update for 1 day';
    return 'No update for $daysSinceUpdate days';
  }
}
