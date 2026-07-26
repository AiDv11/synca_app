/// How far along a task is.
///
/// Lives in `core/constants` rather than next to one role's screens because all
/// three roles read it: a member moves their own task along, a leader watches
/// the whole board, and the coordinator counts how many tasks in a group are
/// [completed] without ever seeing what those tasks say.
///
/// The order of the values is the normal life of a task, and it is deliberate —
/// `TaskStatus.values` comes back in this order, so a status dropdown or a
/// progress bar built from it reads correctly with no extra sorting.
enum TaskStatus {
  notStarted,
  inProgress,
  readyForReview,
  completed;

  /// Turns the string stored in Firestore back into a [TaskStatus].
  ///
  /// Same defensive pattern as `UserRole.fromName`: if the value is missing or
  /// unrecognised — a typo, a hand-edited document, a status added in a later
  /// version of the app — we fall back to [notStarted] rather than crashing.
  /// Falling back to "no work done yet" is the honest guess; it never lets a
  /// broken document make a task look finished.
  static TaskStatus fromName(String? value) => TaskStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => TaskStatus.notStarted,
  );

  /// Human-readable version for the UI.
  ///
  /// `name` gives us the raw enum spelling (`'readyForReview'`), which is right
  /// for Firestore but wrong on screen. Keeping the display text here means all
  /// three roles show a status the same way, and there is one place to change
  /// the wording later.
  ///
  /// A getter on an enum is just a method — Dart enums can hold behaviour, not
  /// only a list of names.
  String get label => switch (this) {
    TaskStatus.notStarted => 'Not started',
    TaskStatus.inProgress => 'In progress',
    TaskStatus.readyForReview => 'Ready for review',
    TaskStatus.completed => 'Completed',
  };

  /// True once the work is done and accepted.
  ///
  /// Small helper, but it saves writing `status == TaskStatus.completed` in
  /// every progress calculation across the three role modules.
  bool get isDone => this == TaskStatus.completed;
}
