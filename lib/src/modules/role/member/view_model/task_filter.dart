import 'package:synca_app/src/core/constants/task_status.dart';
import 'package:synca_app/src/core/services/task_service.dart';

/// Which of the member's claimed tasks the list is showing.
///
/// One value per status, plus [all]. Not simply a `TaskStatus?` — a nullable
/// status would work, but it leaves "null means everything" as an unwritten
/// rule at every call site, and there is nowhere to hang the chip label or the
/// empty-state wording. As an enum, each option carries its own.
///
/// Lives in `view_model` rather than `ui` because it is screen *state*: the
/// ViewModel holds the current value, and it survives the Tasks page being
/// covered by a task detail route.
///
/// This filter is applied **in memory**, over tasks the ViewModel already has.
/// It is deliberately not a Firestore query: the member's whole task list is
/// already streamed for the contribution card, so filtering server-side would
/// mean a second query, a second composite index, and a list that flickers
/// while it reloads on every chip tap.
enum TaskFilter {
  all('All', null),
  toDo('To do', TaskStatus.notStarted),
  inProgress('In progress', TaskStatus.inProgress),
  readyForReview('Ready for review', TaskStatus.readyForReview),
  completed('Completed', TaskStatus.completed);

  const TaskFilter(this.label, this.status);

  /// What the chip says.
  ///
  /// Not always the same as `TaskStatus.label`: the first chip reads "To do"
  /// where the status reads "Not started". On a chip you are choosing what to
  /// look at, and "To do" is what a member calls that pile.
  final String label;

  /// The status this filter keeps, or null for [all].
  final TaskStatus? status;

  /// Does [task] survive this filter?
  bool matches(Task task) => status == null || task.status == status;

  /// Headline when this filter matches nothing.
  ///
  /// [all] is the genuine "you have no tasks" case and keeps the original
  /// wording. The rest say which pile is empty, because "No tasks yet" under an
  /// In progress chip reads as though the list broke rather than as a filter
  /// doing its job.
  String get emptyTitle => switch (this) {
    TaskFilter.all => 'No tasks yet',
    TaskFilter.toDo => 'Nothing left to start',
    TaskFilter.inProgress => 'No tasks in progress',
    TaskFilter.readyForReview => 'Nothing ready for review',
    TaskFilter.completed => 'No completed tasks',
  };

  /// The line under [emptyTitle].
  String get emptyMessage => switch (this) {
    TaskFilter.all =>
      "You haven't claimed anything.\nTap \"Claim a Task\" to pick one up.",
    TaskFilter.toDo =>
      'Everything you have claimed is already under way.\n'
          'Tap All to see the rest.',
    TaskFilter.inProgress =>
      'None of your tasks are being worked on right now.\n'
          'Tap All to see the rest.',
    TaskFilter.readyForReview =>
      'Nothing of yours is waiting to be checked.\nTap All to see the rest.',
    TaskFilter.completed =>
      'You have not finished any of these yet.\nTap All to see the rest.',
  };
}
