import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads and writes the member's chosen avatar on their user document.
///
/// A second service touching `/users` alongside [GroupService] is not ideal.
/// It exists because `AppUser` has no `avatarId` field, so the value cannot
/// ride along with the profile `AuthGate` already loads — and `AppUser` lives
/// in the auth module, outside this one.
///
/// The tidy version is one field on `AppUser` and no service here at all. When
/// that happens, delete this file and read `user.avatarId`.
///
/// Like the other services, this catches nothing. Firestore throws
/// [FirebaseException]; the ViewModel turns it into something readable.
class AvatarService {
  AvatarService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// The member's stored avatar id, or null if they have never chosen one.
  ///
  /// Costs one document read each time the dashboard opens. That is the price
  /// of keeping this out of `AppUser`; folding the field into the profile
  /// fetch would make it free.
  ///
  /// Returns null rather than throwing when the field is absent, because a
  /// document written before this feature existed simply has no `avatarId` —
  /// that is the normal case for every current user, not a failure.
  Future<String?> fetchAvatarId(String uid) async {
    final snapshot = await _users.doc(uid).get();
    return snapshot.data()?['avatarId'] as String?;
  }

  /// Saves the member's choice.
  ///
  /// `update` rather than `set`, so name, email, role and groupId are left
  /// alone — `set` without merge would wipe them.
  ///
  /// Permitted by the deployed security rules without any change: the `/users`
  /// update rule freezes only `role` and `uid`, so any other field on your own
  /// document is yours to write.
  Future<void> setAvatarId({required String uid, required String avatarId}) {
    return _users.doc(uid).update({'avatarId': avatarId});
  }
}
