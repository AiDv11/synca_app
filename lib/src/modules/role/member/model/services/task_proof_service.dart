import 'package:cloud_firestore/cloud_firestore.dart';

/// Changes the proof link on a task without touching its status.
///
/// `TaskService.updateStatus` can already carry a proof link, but only
/// alongside a status change, and it stamps `completedAt` whenever the status
/// is the done one. Correcting a typo in a URL through that path would restamp
/// the completion date of a finished task — so this is a separate, narrower
/// write rather than a flag on the existing one.
///
/// Lives in the member module for the same reason as `TaskOwnershipService`:
/// the change was scoped to `modules/role/member/`. Both are candidates to move
/// next to `claimTask` in `core/services/task_service.dart` if another role ever
/// needs them; three files writing to `/tasks` is two more than ideal.
///
/// Like the other services, this catches nothing. Firestore throws
/// [FirebaseException]; the ViewModel turns it into something readable.
class TaskProofService {
  TaskProofService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _firestore.collection('tasks');

  /// Writes [proofUrl], or removes the proof when it is empty.
  ///
  /// Exactly two fields, and that is load-bearing. The deployed
  /// `isOwnerUpdatingOwnTask` rule permits
  /// `hasOnly(['status', 'proofUrl', 'lastUpdatedAt', 'completedAt'])`, and
  /// `hasOnly` accepts a **subset** — so writing just these two passes with no
  /// rules change. Adding a third field outside that list would break it.
  ///
  /// Removal writes an empty string rather than deleting the field or writing
  /// null. That keeps the shape of the document stable, but it does mean a task
  /// with no proof can hold either `null` (never had any) or `''` (removed).
  /// Every reader must ask `ProofLink.hasProof` rather than checking for null;
  /// a plain null check renders an empty link chip and an unearned "Proof
  /// uploaded" row on the timeline.
  ///
  /// `update`, not `set`: the rest of the document — title, deadline, owner,
  /// status — is left exactly as it was.
  Future<void> setProof({required String taskId, required String proofUrl}) {
    return _tasks.doc(taskId).update({
      'proofUrl': proofUrl,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
  }
}
