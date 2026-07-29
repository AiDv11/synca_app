import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';

/// Reads the people who belong to one group.
///
/// Lives in the leader module because only the leader screens need a live
/// member list (the summary card's count, the Members tab, and the reassign
/// picker).
///
/// ## Why a query on `/users`
///
/// There is no `/groups/{id}/members` collection yet. Membership *is* the
/// `groupId` field on each user document, so the only way to count "how many
/// people are in GROUP1" is to ask Firestore for every user whose `groupId`
/// equals that string.
///
/// That query is legal under `firestore.rules`: a signed-in caller may read
/// profiles in their own group, and naming `groupId` in the filter is what
/// proves every result would pass.
///
/// ## Why there is no `orderBy`
///
/// A `where` on `groupId` plus `orderBy('name')` needs a composite index.
/// The member module already avoids that by sorting on the device. We do the
/// same here so a missing index cannot blank every leader screen.
class GroupMembersService {
  GroupMembersService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Everyone currently in [groupId], updating live, sorted by name in memory.
  Stream<List<AppUser>> streamMembersForGroup(String groupId) {
    return _users.where('groupId', isEqualTo: groupId).snapshots().map((
      snapshot,
    ) {
      final members = snapshot.docs
          .map((doc) => AppUser.fromMap(doc.data()))
          .toList();
      members.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return members;
    });
  }
}
