import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';

/// Reads the people who belong to one group.
///
/// Lives in the leader module because only the leader screens need a live
/// member list (the summary card's count, the Members tab, and the reassign
/// picker). The member module's [GroupService] only writes a groupId onto a
/// profile — it never lists anyone.
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
/// proves every result would pass. An unfiltered `users` collection get is
/// refused outright.
class GroupMembersService {
  GroupMembersService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Everyone currently in [groupId], updating live.
  ///
  /// Ordered by name so the Members tab and the reassign picker stay stable
  /// as people join and leave — without a sort, Firestore returns documents in
  /// document-id order, which looks random on screen.
  ///
  /// A single-field equality filter plus an `orderBy` on a different field
  /// needs a composite index (`groupId` Asc, `name` Asc). The first run without
  /// it throws `failed-precondition` with a console link that creates it.
  Stream<List<AppUser>> streamMembersForGroup(String groupId) {
    return _users
        .where('groupId', isEqualTo: groupId)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => AppUser.fromMap(doc.data())).toList(),
        );
  }
}
