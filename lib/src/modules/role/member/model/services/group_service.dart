import 'package:cloud_firestore/cloud_firestore.dart';

/// Writes a member's group membership to their user document.
///
/// A service rather than Firestore calls inside the ViewModel, because
/// CLAUDE.md keeps Firebase behind a service layer. It lives in the member
/// module rather than `core/services` for the same reason `AuthService` lives
/// in the auth module: only this module uses it. Move it to `core/services`
/// the day the leader module needs to add people to groups.
///
/// Membership currently *is* the `groupId` string on `/users/{uid}`. There is
/// no `/groups` collection yet, so a code is not validated against anything —
/// typing `GROUP1` puts you in a group called `GROUP1` whether or not anyone
/// else is in it. That is a real gap, and it belongs in a `GroupService` that
/// reads a `/groups` collection once one exists.
///
/// Like the other services, this catches nothing. Firestore throws
/// [FirebaseException]; the ViewModel turns that into something readable.
class GroupService {
  GroupService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Sets (or clears) the group on a user's document.
  ///
  /// `update` rather than `set`: the profile already exists — registration
  /// wrote it — and `update` touches only this one field, leaving name, email
  /// and role alone. `set` without merge would wipe them.
  ///
  /// Passing an empty string is how a member leaves; the field stays on the
  /// document as `''`, which is what `AppUser.hasGroup` already tests for.
  ///
  /// Throws if the document doesn't exist (`not-found`), which would mean an
  /// account with no profile — the orphaned-account case `AuthGate` handles.
  Future<void> setGroupId({required String uid, required String groupId}) {
    return _users.doc(uid).update({'groupId': groupId});
  }
}
