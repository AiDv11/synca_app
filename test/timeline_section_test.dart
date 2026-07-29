import 'package:flutter_test/flutter_test.dart';

import 'package:synca_app/src/modules/role/member/view_model/timeline_entry.dart';
import 'package:synca_app/src/modules/role/member/view_model/timeline_section.dart';

/// Tests for the timeline's date grouping.
///
/// `TimelineViewModel` cannot be built in a test — its `TaskService` reaches
/// `FirebaseFirestore.instance` in the constructor — so the grouping was kept
/// out of it as a pure function. This is what that bought.
///
/// Every case pins the clock. A test that read the real date would change
/// meaning overnight: "Wednesday" becomes "Yesterday" and then a bare date, and
/// the suite would start failing on its own.
void main() {
  // A Wednesday, deliberately: it makes the weekday assertions below
  // meaningful rather than accidental.
  final now = DateTime(2026, 7, 29, 14, 30);

  TimelineEntry entryAt(DateTime timestamp, {String taskId = 't1'}) =>
      TimelineEntry(
        type: TimelineEventType.workStarted,
        timestamp: timestamp,
        taskId: taskId,
        taskTitle: 'Literature review',
      );

  String header(DateTime moment) =>
      TimelineSection.headerFor(moment, now: now);

  group('headerFor', () {
    test('names today and yesterday', () {
      expect(header(DateTime(2026, 7, 29, 9)), 'Today');
      expect(header(DateTime(2026, 7, 28, 23, 59)), 'Yesterday');
    });

    test('uses the weekday for the rest of the last week', () {
      expect(header(DateTime(2026, 7, 27)), 'Monday');
      expect(header(DateTime(2026, 7, 26)), 'Sunday');
      // Six days back is the last day that still gets a weekday name.
      expect(header(DateTime(2026, 7, 23)), 'Thursday');
    });

    test('falls back to a date at seven days', () {
      // The boundary: a weekday name stops being useful here, because
      // "Wednesday" would be ambiguous between two Wednesdays.
      expect(header(DateTime(2026, 7, 22)), '22 Jul');
      expect(header(DateTime(2026, 3, 4)), '4 Mar');
    });

    test('time of day never shifts the header', () {
      // Both ends of the same day land under the same heading.
      expect(header(DateTime(2026, 7, 28, 0, 0)), 'Yesterday');
      expect(header(DateTime(2026, 7, 28, 23, 59, 59)), 'Yesterday');
    });

    test('a future timestamp lands under Today', () {
      // Means the device clock and the server disagree. Inventing a header for
      // a day that has not happened would be worse than rounding.
      expect(header(DateTime(2026, 8, 5)), 'Today');
    });
  });

  group('group', () {
    test('cuts consecutive entries into days', () {
      final sections = TimelineSection.group([
        entryAt(DateTime(2026, 7, 29, 14)),
        entryAt(DateTime(2026, 7, 29, 9)),
        entryAt(DateTime(2026, 7, 28, 16)),
        entryAt(DateTime(2026, 7, 27, 11)),
      ], now: now);

      expect(sections.map((s) => s.header), ['Today', 'Yesterday', 'Monday']);
      expect(sections[0].entries.length, 2);
      expect(sections[1].entries.length, 1);
      expect(sections[2].entries.length, 1);
    });

    test('keeps entry order within a day', () {
      final first = entryAt(DateTime(2026, 7, 29, 14), taskId: 'a');
      final second = entryAt(DateTime(2026, 7, 29, 9), taskId: 'b');

      final sections = TimelineSection.group([first, second], now: now);

      expect(sections.single.entries.map((e) => e.taskId), ['a', 'b']);
    });

    test('groups by the day, not by the header text', () {
      // Both render as "4 Mar". Grouping on the string would fold two years
      // into one section claiming to be a single day.
      final sections = TimelineSection.group([
        entryAt(DateTime(2026, 3, 4)),
        entryAt(DateTime(2025, 3, 4)),
      ], now: now);

      expect(sections.length, 2);
      expect(sections.every((s) => s.header == '4 Mar'), isTrue);
    });

    test('an empty timeline produces no sections', () {
      expect(TimelineSection.group(const [], now: now), isEmpty);
    });

    test('every entry survives grouping', () {
      final entries = [
        entryAt(DateTime(2026, 7, 29, 14)),
        entryAt(DateTime(2026, 7, 28, 16)),
        entryAt(DateTime(2026, 7, 28, 8)),
        entryAt(DateTime(2026, 1, 2)),
      ];

      final grouped = TimelineSection.group(entries, now: now)
          .expand((s) => s.entries)
          .toList();

      // Grouping must not drop or duplicate anything — it only inserts breaks.
      expect(grouped.length, entries.length);
    });
  });
}
