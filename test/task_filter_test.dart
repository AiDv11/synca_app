import 'package:flutter_test/flutter_test.dart';

import 'package:synca_app/src/core/constants/task_status.dart';
import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/modules/role/member/view_model/task_filter.dart';

/// Tests for the My Tasks filter chips.
///
/// Worth testing despite being small: the mapping from a chip to a status is
/// exactly the kind of thing that survives a careless edit while quietly
/// selecting the wrong pile — "To do" is the one whose label and status
/// deliberately disagree, so nothing about it looks wrong on inspection.
///
/// No Firebase needed. `Task` is a plain Dart object, and `TaskFilter.matches`
/// only reads its status.
void main() {
  Task taskWith(TaskStatus status) => Task(
    id: 't1',
    groupId: 'GROUP1',
    title: 'Literature review',
    description: '',
    ownerUid: 'uid1',
    ownerName: 'Ali',
    status: status,
    deadline: DateTime(2026, 8, 1),
    createdAt: DateTime(2026, 7, 1),
    lastUpdatedAt: DateTime(2026, 7, 1),
  );

  test('All keeps every status', () {
    for (final status in TaskStatus.values) {
      expect(
        TaskFilter.all.matches(taskWith(status)),
        isTrue,
        reason: 'All should keep $status',
      );
    }
  });

  test('each chip keeps exactly its own status', () {
    const pairs = {
      TaskFilter.toDo: TaskStatus.notStarted,
      TaskFilter.inProgress: TaskStatus.inProgress,
      TaskFilter.readyForReview: TaskStatus.readyForReview,
      TaskFilter.completed: TaskStatus.completed,
    };

    pairs.forEach((filter, kept) {
      for (final status in TaskStatus.values) {
        expect(
          filter.matches(taskWith(status)),
          status == kept,
          reason: '$filter should ${status == kept ? 'keep' : 'drop'} $status',
        );
      }
    });
  });

  test('"To do" maps to notStarted despite the different wording', () {
    // The one pair where the chip label and the status label disagree on
    // purpose. If someone "fixes" the label to match, this still passes; if
    // they rewire it to a different status, it does not.
    expect(TaskFilter.toDo.label, 'To do');
    expect(TaskFilter.toDo.status, TaskStatus.notStarted);
    expect(TaskStatus.notStarted.label, 'Not started');
  });

  test('every filter has its own empty wording', () {
    final titles = TaskFilter.values.map((f) => f.emptyTitle).toSet();

    // Distinct, so the screen never says "No tasks yet" under an In progress
    // chip — which reads as a broken list rather than an empty pile.
    expect(titles.length, TaskFilter.values.length);

    // All keeps the original copy, including the prompt to claim something.
    expect(TaskFilter.all.emptyTitle, 'No tasks yet');
    expect(TaskFilter.all.emptyMessage, contains('Claim a Task'));
  });
}
