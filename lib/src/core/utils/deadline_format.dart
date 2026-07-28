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

  /// Whole days from today until [deadline]. Negative once it has passed, `0`
  /// on the day itself.
  ///
  /// Whole days, not exact instants, and that is the important part. Without
  /// it a deadline three hours away would be "0 days", and a task due at 9am
  /// would flip to overdue at 10am on the very morning it is due —
  /// technically true, and not how anybody thinks about a coursework deadline.
  /// A due date means "by the end of that day".
  ///
  /// [now] is a parameter with a default instead of always calling
  /// `DateTime.now()` inside. Real code omits it; a test can pass a fixed date
  /// and get a predictable answer. Anything that reads the clock is otherwise
  /// almost impossible to test.
  static int daysUntil(DateTime deadline, {DateTime? now}) {
    final today = _startOfDay(now ?? DateTime.now());
    final due = _startOfDay(deadline);
    return due.difference(today).inDays;
  }

  /// True when [deadline] fell on an earlier day than today and the work is
  /// still not finished.
  ///
  /// [isDone] is a plain bool rather than a `TaskStatus` on purpose: this file
  /// is about dates, and taking the enum would tie a core date utility to the
  /// task model. The caller passes `task.status.isDone`.
  ///
  /// Finished work is never overdue, however old the deadline — handing a
  /// completed task a red card because it was submitted late would be nagging
  /// about something that cannot be acted on any more.
  ///
  /// Deliberately the *same* day-level arithmetic as [relative], so the card's
  /// red accent and its wording can never disagree. Two separate notions of
  /// "past" is exactly how a card ends up flagged overdue while its own text
  /// reads "Due today".
  static bool isOverdue(
    DateTime deadline, {
    required bool isDone,
    DateTime? now,
  }) {
    if (isDone) return false;
    return daysUntil(deadline, now: now) < 0;
  }

  /// A human phrase for how close a deadline is: `'Due today'`,
  /// `'3 days left'`, `'Due in 2 weeks'`, `'2 days overdue'`.
  ///
  /// A countdown rather than a bare date, because "Due 14 Aug" makes the reader
  /// do the arithmetic themselves — and the answer they actually want is how
  /// much time is left.
  ///
  /// Finished work is the one exception: it gets the plain date. A countdown on
  /// a completed task is meaningless in both directions, since neither "3 days
  /// left" nor "2 days overdue" describes anything the member still has to do.
  static String relative(
    DateTime deadline, {
    bool isDone = false,
    DateTime? now,
  }) {
    if (isDone) return 'Due ${dayAndMonth(deadline)}';

    final days = daysUntil(deadline, now: now);

    if (days == -1) return '1 day overdue';
    if (days < 0) return '${-days} days overdue';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    if (days < 7) return '$days days left';

    // Integer division, so 7–13 days is "1 week" and 14–20 is "2 weeks". It
    // rounds down, which is the safe direction: a deadline 13 days out reading
    // as one week away never makes anybody think they have more time than they
    // do.
    final weeks = days ~/ 7;
    if (weeks == 1) return 'Due in 1 week';
    return 'Due in $weeks weeks';
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
