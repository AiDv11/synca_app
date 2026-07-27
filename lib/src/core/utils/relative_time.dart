import 'package:synca_app/src/core/utils/deadline_format.dart';

/// Turns a moment in the **past** into "3 days ago"-style text.
///
/// The sibling of [DeadlineFormat], which looks forward at due dates. Both
/// exist because they read differently: a deadline is "Due in 3 days", history
/// is "3 days ago", and one class trying to do both ends up with a `isPast`
/// flag threaded through every call.
abstract final class RelativeTime {
  /// How long ago [moment] was.
  ///
  /// [now] is injectable so tests can pin the clock — the same reasoning as
  /// [DeadlineFormat.relative]. Anything that reads `DateTime.now()` internally
  /// is close to untestable.
  static String past(DateTime moment, {DateTime? now}) {
    final current = now ?? DateTime.now();

    // A timestamp in the future means a clock disagreement — the device's or
    // the writer's. "In 4 hours" on a history screen looks like a bug, so it is
    // rounded to the least surprising thing instead.
    if (moment.isAfter(current)) return 'Just now';

    final elapsed = current.difference(moment);

    if (elapsed.inMinutes < 1) return 'Just now';
    if (elapsed.inMinutes < 60) {
      final minutes = elapsed.inMinutes;
      return minutes == 1 ? '1 minute ago' : '$minutes minutes ago';
    }
    if (elapsed.inHours < 24) {
      final hours = elapsed.inHours;
      return hours == 1 ? '1 hour ago' : '$hours hours ago';
    }

    // Past a day, switch from elapsed time to calendar days. `elapsed.inDays`
    // counts 24-hour blocks, so something at 11pm last night would be "0 days"
    // at 8am today — but a person calls that yesterday.
    final days = _startOfDay(current).difference(_startOfDay(moment)).inDays;

    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';

    // Beyond a week, counting stops being useful and a date is clearer.
    return DeadlineFormat.dayAndMonth(moment);
  }

  /// A clock time, `'14:05'`, for entries from today.
  ///
  /// `padLeft(2, '0')` is what turns 9:5 into 09:05.
  static String clock(DateTime moment) {
    final hour = moment.hour.toString().padLeft(2, '0');
    final minute = moment.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
