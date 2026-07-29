import 'package:synca_app/src/core/utils/deadline_format.dart';
import 'package:synca_app/src/modules/role/member/view_model/timeline_entry.dart';

/// A run of timeline entries that happened on the same day, under one header.
///
/// Grouping only — this does **not** derive entries or change their order. It
/// takes the list `TimelineViewModel` already produced, newest first, and cuts
/// it into days. Feed it a different list and it groups that instead.
///
/// A pure function on a plain class rather than logic inside the page, for the
/// same reason `GroupMember.sortedForViewer` is: `TimelineViewModel` cannot be
/// built in a test — its `TaskService` reaches `FirebaseFirestore.instance` in
/// the constructor — so anything worth pinning has to live outside it.
class TimelineSection {
  const TimelineSection({required this.header, required this.entries});

  /// 'Today', 'Yesterday', 'Monday', or '14 Aug'.
  final String header;

  /// The entries for this day, in the order they arrived — newest first.
  final List<TimelineEntry> entries;

  /// Indexed by `DateTime.weekday`, which runs 1–7 starting at Monday. The
  /// leading empty string absorbs the unused index 0 so the lookup needs no
  /// `- 1` and cannot be off by one.
  static const List<String> _weekdays = [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// The header a moment belongs under.
  ///
  /// The ladder is deliberately the one people use out loud: today and
  /// yesterday have names, the rest of the week is known by its weekday, and
  /// past that a weekday stops being useful — "Tuesday" could be any Tuesday —
  /// so it becomes a date.
  ///
  /// [now] is injectable so a test can pin the clock, the same reasoning as
  /// [DeadlineFormat.relative]. Anything reading `DateTime.now()` internally is
  /// close to untestable.
  ///
  /// A timestamp in the future means the device's clock and the server's
  /// disagree. It lands under Today rather than inventing a header for a day
  /// that has not happened — the same choice `RelativeTime.past` makes when it
  /// rounds the future to "Just now".
  static String headerFor(DateTime moment, {DateTime? now}) {
    final today = _startOfDay(now ?? DateTime.now());
    final day = _startOfDay(moment);
    final daysAgo = today.difference(day).inDays;

    if (daysAgo <= 0) return 'Today';
    if (daysAgo == 1) return 'Yesterday';
    if (daysAgo < 7) return _weekdays[day.weekday];
    return DeadlineFormat.dayAndMonth(moment);
  }

  /// Cuts [entries] into consecutive same-day runs.
  ///
  /// Grouped by the **day itself**, not by the header text. Two entries a year
  /// apart can both render as '14 Aug', and grouping on the string would fold
  /// them into one section that claims to be a single day.
  ///
  /// A single pass, relying on the list already being ordered by time. That is
  /// what `TimelineViewModel` produces; handing this a shuffled list would give
  /// repeated headers rather than an error, which is the honest outcome — it is
  /// a grouper, not a sorter.
  static List<TimelineSection> group(
    List<TimelineEntry> entries, {
    DateTime? now,
  }) {
    final sections = <TimelineSection>[];

    DateTime? openDay;
    var openEntries = <TimelineEntry>[];

    void closeOpenSection() {
      // Copied into a local first so the null check promotes it — cleaner than
      // asserting with `!` on a variable the closure also reassigns.
      final day = openDay;
      if (day == null) return;

      sections.add(
        TimelineSection(
          header: headerFor(day, now: now),
          entries: List.unmodifiable(openEntries),
        ),
      );
    }

    for (final entry in entries) {
      final day = _startOfDay(entry.timestamp);

      // DateTime's `==` compares the instant, and every value here is midnight,
      // so same-day values really are equal.
      if (day != openDay) {
        closeOpenSection();
        openDay = day;
        openEntries = [entry];
      } else {
        openEntries.add(entry);
      }
    }

    closeOpenSection();
    return List.unmodifiable(sections);
  }

  static DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
