/// Turns a deadline [DateTime] into the short phrases the UI shows.
///
/// Lives in `core/utils` because every role will want it — a member's task
/// card, a leader's at-risk list, a coordinator's "groups with overdue work".
/// Written by hand rather than pulling in the `intl` package: the app needs
/// four phrases and a day-month string, which isn't worth a dependency.
///
/// `abstract final` makes this a namespace only — no `DeadlineFormat()` object
/// can be created and nothing can extend it. Same pattern as `AppColors`.
abstract final class DeadlineFormat {
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// A human phrase for how close a deadline is: `'Due today'`,
  /// `'2 days overdue'`, `'Due 14 Aug'`.
  ///
  /// [now] is a parameter with a default instead of always calling
  /// `DateTime.now()` inside. Real code omits it; a test can pass a fixed date
  /// and get a predictable answer. Anything that reads the clock is otherwise
  /// almost impossible to test.
  static String relative(DateTime deadline, {DateTime? now}) {
    // Compare whole days, not exact instants. Without this, a deadline three
    // hours from now would be "0 days" and a deadline at 9am today would read
    // as overdue at 10am — technically true, but not how people think about a
    // coursework due date.
    final today = _startOfDay(now ?? DateTime.now());
    final due = _startOfDay(deadline);
    final days = due.difference(today).inDays;

    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    if (days == -1) return '1 day overdue';
    if (days < 0) return '${-days} days overdue';
    if (days < 7) return 'Due in $days days';
    return 'Due ${dayAndMonth(deadline)}';
  }

  /// A plain date, e.g. `'14 Aug'`. Used once a deadline is far enough away
  /// that counting days stops being useful.
  ///
  /// `_months` is zero-indexed but `DateTime.month` runs 1–12, hence the `- 1`.
  static String dayAndMonth(DateTime date) =>
      '${date.day} ${_months[date.month - 1]}';

  /// Strips the time off a date, leaving midnight on the same day.
  static DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
