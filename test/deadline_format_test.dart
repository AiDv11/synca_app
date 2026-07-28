import 'package:flutter_test/flutter_test.dart';

import 'package:synca_app/src/core/utils/deadline_format.dart';

/// Tests for the deadline arithmetic behind the member task cards.
///
/// Worth testing where most UI code is not: this is pure logic with a lot of
/// boundaries — the day a task is due, the day after, the jump from days to
/// weeks — and every one of them is off-by-one bait. It also has no Firebase
/// and no widgets in the way, so it runs in milliseconds.
///
/// Every case passes an explicit [now]. `DeadlineFormat` reads the clock only
/// when that argument is omitted, which is exactly why the parameter exists:
/// a test that depended on the real date would quietly change meaning
/// overnight and start failing on its own.
void main() {
  // A fixed "today" so none of this depends on when it is run.
  final now = DateTime(2026, 7, 28, 14, 30);

  String phrase(DateTime deadline, {bool isDone = false}) =>
      DeadlineFormat.relative(deadline, isDone: isDone, now: now);

  bool overdue(DateTime deadline, {bool isDone = false}) =>
      DeadlineFormat.isOverdue(deadline, isDone: isDone, now: now);

  test('the countdown ladder', () {
    expect(phrase(DateTime(2026, 7, 21)), '7 days overdue');
    expect(phrase(DateTime(2026, 7, 26)), '2 days overdue');
    expect(phrase(DateTime(2026, 7, 27)), '1 day overdue');
    expect(phrase(DateTime(2026, 7, 28)), 'Due today');
    expect(phrase(DateTime(2026, 7, 29)), 'Due tomorrow');
    expect(phrase(DateTime(2026, 7, 31)), '3 days left');
    expect(phrase(DateTime(2026, 8, 3)), '6 days left');
    expect(phrase(DateTime(2026, 8, 4)), 'Due in 1 week');
    expect(phrase(DateTime(2026, 8, 10)), 'Due in 1 week');
    expect(phrase(DateTime(2026, 8, 11)), 'Due in 2 weeks');
    expect(phrase(DateTime(2026, 9, 8)), 'Due in 6 weeks');
  });

  test('time of day never tips a deadline over', () {
    // Due at 9am, read at 2.30pm the same day. Still due today, not overdue —
    // a due date means "by the end of that day", not "by that instant".
    expect(phrase(DateTime(2026, 7, 28, 9)), 'Due today');
    expect(overdue(DateTime(2026, 7, 28, 9)), isFalse);

    // Both sides of midnight: the last minute of today is not late, the last
    // minute of yesterday is.
    expect(overdue(DateTime(2026, 7, 28, 23, 59)), isFalse);
    expect(overdue(DateTime(2026, 7, 27, 23, 59)), isTrue);
  });

  test('a completed task is never overdue, however old', () {
    final ancient = DateTime(2020, 1, 5);

    expect(overdue(ancient, isDone: true), isFalse);
    expect(overdue(ancient, isDone: false), isTrue);

    // And it stops counting down in either direction, because neither
    // "3 days left" nor "2 days overdue" describes anything still to do.
    expect(phrase(ancient, isDone: true), 'Due 5 Jan');
    expect(phrase(DateTime(2026, 8, 11), isDone: true), 'Due 11 Aug');
  });

  test('isOverdue and relative agree on every boundary', () {
    // The whole reason both are built on daysUntil. No date may be red-flagged
    // on the card while the card's own wording says it is not late.
    for (var offset = -5; offset <= 5; offset++) {
      final deadline = DateTime(2026, 7, 28 + offset);
      final saysOverdue = phrase(deadline).contains('overdue');
      expect(
        overdue(deadline),
        saysOverdue,
        reason: 'offset $offset: flag and wording disagree',
      );
    }
  });
}
