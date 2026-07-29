import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:synca_app/src/core/constants/task_status.dart';
import 'package:synca_app/src/core/services/task_service.dart';

/// Gives a task back to the group.
///
/// The opposite of `TaskService.claimTask`, and it lives here rather than
/// beside it because this change is scoped to the member module. If unclaim
/// ever becomes something a leader does too, this belongs in
/// `core/services/task_service.dart` next to `claimTask` and `reassignTask` —
/// two files writing to `/tasks` is a seam, and the tidy version has one.
///
/// Permitted by the deployed rules through `isOwnerReleasingTask()` (Case 3
/// under `/tasks`), which exists for this write specifically. That rule pins
/// the incoming `ownerUid` to the empty string, so this may hand a task back to
/// *nobody* but can never hand it to a *named* person — reassignment stays a
/// leader's power. The field list below must keep matching the rule's
/// `hasOnly`, or every release starts failing.
///
/// Like the other services, this catches nothing. Firestore throws
/// [FirebaseException]; the ViewModel turns it into something readable.
class TaskOwnershipService {
  TaskOwnershipService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _firestore.collection('tasks');

  /// Clears the owner so the task returns to the claim sheet.
  ///
  /// A **transaction**, for the same reason `claimTask` uses one: the document
  /// can change between reading it and writing it. Here the race is a leader
  /// reassigning the task at the moment the member releases it. Without the
  /// transaction the release would land second and quietly undo the leader's
  /// decision; with it, the block re-runs against fresh data and the ownership
  /// check below fails honestly.
  ///
  /// Throws [StateError] if the task is gone or is no longer this member's.
  /// The ViewModel catches it and shows the message.
  ///
  /// ## What it writes, and why each field
  ///
  /// - `ownerUid` / `ownerName` — cleared. This is the release itself.
  /// - `claimedAt` — nulled. It records *this* member's claim; leaving it would
  ///   date an unclaimed task to a claim that has been undone. Nothing is lost:
  ///   the member's timeline is built from tasks they own, so a released task
  ///   leaves it either way.
  /// - `status` — back to `notStarted`. The claim sheet is built on unclaimed
  ///   work being fresh work, and `TaskCard` hides the status chip there for
  ///   exactly that reason. Dropping a half-finished task into the pool still
  ///   labelled "In progress" would be a lie about work nobody is doing.
  /// - `lastUpdatedAt` — server time, as every write in this app does.
  ///
  /// `proofUrl` is deliberately **left alone**. It is evidence of work that
  /// really happened, and this app exists to keep that. It does mean a released
  /// task can carry a proof link from its previous owner — odd-looking, but far
  /// better than quietly destroying somebody's record of what they did.
  Future<void> releaseTask({required String taskId, required String uid}) {
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

      if (currentOwner != uid) {
        throw StateError(
          currentOwner == Task.unassigned
              ? 'That task is already back with the group.'
              : 'That task now belongs to '
                    '${data['ownerName'] as String? ?? 'someone else'}.',
        );
      }

      transaction.update(ref, {
        'ownerUid': Task.unassigned,
        'ownerName': '',
        'claimedAt': null,
        'status': TaskStatus.notStarted.name,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
