import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/task_status.dart';

/// A single piece of coursework, as stored in the `tasks` collection.
///
/// One flat collection holds every task in the app, each one tagged with the
/// `groupId` it belongs to. Queries then filter by group. The alternative —
/// nesting tasks underneath each group document — makes "all tasks for this
/// user across their groups" much harder to ask for, which is exactly what a
/// member's contribution timeline needs.
class Task {
  const Task({
    required this.id,
    required this.groupId,
    required this.title,
    required this.description,
    required this.ownerUid,
    required this.ownerName,
    required this.status,
    required this.deadline,
    required this.createdAt,
    required this.lastUpdatedAt,
    this.proofUrl,
  });

  /// The Firestore document id.
  ///
  /// Unlike a user's uid, we don't choose this — Firestore generates it when
  /// the task is created. It is not stored *inside* the document (that would be
  /// the same string written twice, free to drift apart); it is read off the
  /// snapshot in [Task.fromMap] instead.
  final String id;

  /// Which group this task belongs to. Every query filters on it.
  final String groupId;

  final String title;
  final String description;

  /// The member responsible, or [unassigned] if nobody has claimed it yet.
  final String ownerUid;

  /// The owner's display name, copied onto the task when it is claimed.
  ///
  /// Yes, this duplicates the name already in the `users` collection. That's
  /// intentional and normal in Firestore — it's called denormalising. Without
  /// it, drawing a list of twenty tasks means twenty extra reads to look up
  /// twenty names. The trade-off is that if someone changes their display name,
  /// tasks they already own keep the old one until reassigned.
  final String ownerName;

  final TaskStatus status;

  /// When the work is due. Used for sorting and for at-risk flags.
  final DateTime deadline;

  final DateTime createdAt;

  /// Touched by every write, so "who did what, when" can be reconstructed and
  /// so a group's activity can be judged as fresh or stale.
  final DateTime lastUpdatedAt;

  /// Link to the uploaded proof of work, or null if none has been attached.
  ///
  /// Nullable because "no proof yet" is a real, expected state — not an error.
  /// Dart's null safety then forces callers to handle that case.
  ///
  /// Private group content: the Module Coordinator must never be shown this.
  final String? proofUrl;

  /// The value of [ownerUid] when a task is sitting in the pool for anyone to
  /// claim. An empty string rather than null keeps the field's type simple and
  /// keeps the Firestore query in [TaskService.streamTasksForUser] working —
  /// a real uid is never empty, so there is no ambiguity.
  static const String unassigned = '';

  /// True when somebody has taken responsibility for this task.
  bool get isClaimed => ownerUid != unassigned;

  /// True when the deadline has passed and the work still isn't done.
  ///
  /// A computed getter, not a stored field: it depends on the current time, so
  /// storing it would mean a value that silently goes stale in the database.
  bool get isOverdue => !status.isDone && deadline.isBefore(DateTime.now());

  /// Converts this object into the plain `Map` Firestore stores.
  ///
  /// Two conversions matter here. The enum is written as its name — the string
  /// `'inProgress'` — because Firestore can't store a Dart enum. And each
  /// `DateTime` becomes a [Timestamp], Firestore's own date type; writing a raw
  /// `DateTime` would throw.
  ///
  /// [id] is left out on purpose: it is the document's name, not a field in it.
  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'title': title,
      'description': description,
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'status': status.name,
      'deadline': Timestamp.fromDate(deadline),
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdatedAt': Timestamp.fromDate(lastUpdatedAt),
      'proofUrl': proofUrl,
    };
  }

  /// Builds a [Task] from a Firestore document.
  ///
  /// Takes the id separately because, as above, it doesn't live in the map —
  /// callers pass `snapshot.id` alongside `snapshot.data()`.
  ///
  /// Every field is read defensively. `map['title']` is typed `dynamic`, so
  /// `as String?` says "treat this as a nullable String" and `?? ''` supplies a
  /// fallback. A half-written document should render as a blank-ish task, not
  /// crash the screen it appears on.
  factory Task.fromMap(String id, Map<String, dynamic> map) {
    return Task(
      id: id,
      groupId: map['groupId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      ownerUid: map['ownerUid'] as String? ?? unassigned,
      ownerName: map['ownerName'] as String? ?? '',
      status: TaskStatus.fromName(map['status'] as String?),
      deadline: _readDate(map['deadline']),
      createdAt: _readDate(map['createdAt']),
      lastUpdatedAt: _readDate(map['lastUpdatedAt']),
      // No `?? ''` here — null is the meaningful "no proof uploaded" value.
      proofUrl: map['proofUrl'] as String?,
    );
  }

  /// Reads a Firestore [Timestamp] back into a Dart [DateTime].
  ///
  /// The `is` check both tests the type and narrows it, so `value.toDate()` on
  /// the next line compiles without a cast — Dart calls that promotion.
  ///
  /// A missing or malformed date falls back to the epoch (1 Jan 1970) rather
  /// than to `DateTime.now()`. That's on purpose: an ancient date shows up as
  /// glaringly overdue in the UI, whereas "now" would quietly look plausible
  /// and hide the broken document.
  static DateTime _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  String toString() =>
      'Task(id: $id, title: $title, status: ${status.name}, owner: $ownerName)';
}

/// Everything to do with reading and writing tasks.
///
/// Deliberately role-agnostic. It has no idea whether the caller is a member, a
/// leader or a coordinator, and it enforces no permissions — that belongs in
/// the ViewModels above it and in Firestore security rules below it. Keeping
/// the service dumb is what lets all three role modules share one file instead
/// of growing three near-identical copies.
///
/// **Coordinator note:** a coordinator ViewModel may call
/// [streamTasksForGroup] to count progress, but must only ever surface
/// aggregates — never `title`, `description` or `proofUrl`. This class cannot
/// enforce that; the ViewModel must.
///
/// Like `AuthService`, none of these methods catch errors. Firestore throws
/// [FirebaseException] on a permission or network failure, and the ViewModel is
/// the right layer to turn that into a message a student can read.
class TaskService {
  /// Firestore is a constructor parameter with a default rather than being
  /// hardcoded in each method. App code writes `TaskService()` and gets the
  /// real database; a test can pass in a fake.
  TaskService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Shorthand for the `tasks` collection so the name is spelled once. A typo
  /// in a collection name doesn't error — it silently reads an empty
  /// collection, which is a miserable bug to track down.
  CollectionReference<Map<String, dynamic>> get _tasks =>
      _firestore.collection('tasks');

  /// Adds a new task to a group.
  ///
  /// A leader normally creates tasks, but nothing here checks that — see the
  /// class note on why.
  ///
  /// Leave [ownerUid] and [ownerName] out and the task lands in the pool for
  /// anyone to [claimTask]; pass them and it is assigned from the start.
  ///
  /// `async`/`await`: writing to Firestore goes over the network, so this
  /// returns a `Future<Task>` — "a Task, eventually". `await` pauses the method
  /// until the write finishes without freezing the UI.
  ///
  /// Returns the created [Task] so the caller has the generated id straight
  /// away, rather than waiting for the stream to deliver it.
  Future<Task> createTask({
    required String groupId,
    required String title,
    required String description,
    required DateTime deadline,
    String ownerUid = Task.unassigned,
    String ownerName = '',
  }) async {
    // One timestamp for both fields, so a brand new task reads as "created and
    // last updated at the same instant" — which is exactly what happened.
    //
    // This is the device's clock. `FieldValue.serverTimestamp()` would use
    // Firebase's clock and be immune to a wrong phone clock, but it writes null
    // first and fills in a moment later, which every reader then has to handle.
    // Not worth the complexity here.
    final now = DateTime.now();

    // `.doc()` with no argument generates an id locally, without a round trip,
    // so we know the id before the write is even sent.
    final ref = _tasks.doc();

    final task = Task(
      id: ref.id,
      groupId: groupId,
      title: title.trim(),
      description: description.trim(),
      ownerUid: ownerUid,
      ownerName: ownerName.trim(),
      status: TaskStatus.notStarted,
      deadline: deadline,
      createdAt: now,
      lastUpdatedAt: now,
      proofUrl: null,
    );

    await ref.set(task.toMap());

    return task;
  }

  /// A member takes an unclaimed task for themselves.
  ///
  /// This runs in a **transaction** because two members can tap "claim" on the
  /// same task at the same moment. A plain `update` would let the second write
  /// silently overwrite the first, and one of them would do work that was no
  /// longer theirs. A transaction reads and writes as one indivisible step: if
  /// the document changed in between, Firebase runs the whole block again with
  /// the fresh data, so the second member reliably sees the task as taken.
  ///
  /// Throws [StateError] if the task has vanished or somebody else already owns
  /// it. The ViewModel should catch that and show "already claimed".
  /// Re-claiming a task you already own is allowed and does nothing harmful.
  ///
  /// Claiming does not change the [TaskStatus] — taking responsibility isn't
  /// the same as starting work. The member moves it to
  /// [TaskStatus.inProgress] themselves via [updateStatus].
  Future<void> claimTask({
    required String taskId,
    required String uid,
    required String name,
  }) {
    final ref = _tasks.doc(taskId);

    return _firestore.runTransaction((transaction) async {
      // Reads inside a transaction must go through `transaction.get`, not
      // `ref.get` — that's how Firebase knows what to re-check for conflicts.
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();

      if (data == null) {
        throw StateError('That task no longer exists.');
      }

      final currentOwner = data['ownerUid'] as String? ?? Task.unassigned;
      if (currentOwner != Task.unassigned && currentOwner != uid) {
        final currentOwnerName = data['ownerName'] as String? ?? 'someone else';
        throw StateError('That task was already claimed by $currentOwnerName.');
      }

      transaction.update(ref, {
        'ownerUid': uid,
        'ownerName': name.trim(),
        'lastUpdatedAt': Timestamp.fromDate(DateTime.now()),
      });
    });
  }

  /// Moves a task along its lifecycle, optionally attaching proof of work.
  ///
  /// [proofUrl] is optional so a member can upload their evidence and flip the
  /// task to [TaskStatus.readyForReview] in a single write — two writes would
  /// leave a window where the status claims work is ready but the proof isn't
  /// there yet.
  ///
  /// `update` writes only the named fields and leaves the rest of the document
  /// alone, where `set` would replace the whole thing. The `?` in
  /// `'proofUrl': ?proofUrl` is a *null-aware element*: it drops the entry
  /// entirely when the value is null, instead of writing null into it. So
  /// calling this without proof leaves any proof already on the task untouched
  /// rather than wiping it.
  Future<void> updateStatus({
    required String taskId,
    required TaskStatus status,
    String? proofUrl,
  }) {
    return _tasks.doc(taskId).update({
      'status': status.name,
      'lastUpdatedAt': Timestamp.fromDate(DateTime.now()),
      'proofUrl': ?proofUrl,
    });
  }

  /// Hands a task to a different member — a leader rebalancing the workload.
  ///
  /// Unlike [claimTask] this overwrites whoever currently owns the task, with
  /// no transaction and no "already taken" check, because that is the point: a
  /// leader's decision wins. Pass [Task.unassigned] and an empty name to drop
  /// the task back into the pool.
  ///
  /// The status is left alone; moving work between people doesn't undo it.
  Future<void> reassignTask({
    required String taskId,
    required String ownerUid,
    required String ownerName,
  }) {
    return _tasks.doc(taskId).update({
      'ownerUid': ownerUid,
      'ownerName': ownerName.trim(),
      'lastUpdatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Every task in one group, soonest deadline first, updating live.
  ///
  /// A `Stream` is "many values over time", where a `Future` is "one value,
  /// once". `.snapshots()` pushes a fresh list every time any task in the group
  /// changes — including changes made by other people on other devices. A
  /// leader's dashboard rebuilds the moment a member marks something done,
  /// with no refresh button and no polling.
  ///
  /// `.map()` here is the *stream's* map: it converts each incoming snapshot
  /// into a `List<Task>` as it arrives, so the ViewModel receives models rather
  /// than raw Firestore objects.
  ///
  /// Feeds the leader dashboard and the coordinator's aggregate counts.
  Stream<List<Task>> streamTasksForGroup(String groupId) {
    return _tasks
        .where('groupId', isEqualTo: groupId)
        .orderBy('deadline')
        .snapshots()
        .map(_toTasks);
  }

  /// Every task one member owns, across all their groups, soonest deadline
  /// first. Feeds a member's "my tasks" list and contribution timeline.
  ///
  /// Because unclaimed tasks store [Task.unassigned] (an empty string) rather
  /// than null, they simply never match a real uid — no special case needed.
  ///
  /// Heads-up: filtering on one field and ordering by another needs a
  /// **composite index** in Firestore. The first time this runs you'll get a
  /// `failed-precondition` error in the debug console with a link that creates
  /// the index for you — click it once and it's done.
  Stream<List<Task>> streamTasksForUser(String uid) {
    return _tasks
        .where('ownerUid', isEqualTo: uid)
        .orderBy('deadline')
        .snapshots()
        .map(_toTasks);
  }

  /// Turns a query result into models. Shared by both streams so the id-plus-
  /// data pairing is written once.
  List<Task> _toTasks(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs
        .map((doc) => Task.fromMap(doc.id, doc.data()))
        .toList();
  }
}
