import 'package:cloud_firestore/cloud_firestore.dart';

/// Writes the leader's `groupId` onto their user document.
///
/// Leader-module copy of the member `GroupService.setGroupId` path so this
/// folder does not import `modules/role/member`. Membership is still just the
/// string on `/users/{uid}` — there is no `/groups` collection to validate
/// against, so any non-empty code creates/joins that group id.
class GroupMembershipService {
  GroupMembershipService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> setGroupId({required String uid, required String groupId}) {
    return _firestore.collection('users').doc(uid).update({
      'groupId': groupId,
    });
  }
}
