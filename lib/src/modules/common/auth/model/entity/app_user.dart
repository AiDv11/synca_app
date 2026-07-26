/// The three kinds of user in Synca.
///
/// The role decides which screens a user sees and what they are allowed to do,
/// so it is stored on the user's Firestore document and read back on login.
enum UserRole {
  member,
  leader,
  coordinator;

  /// Turns the string stored in Firestore back into a [UserRole].
  ///
  /// If the value is missing or unrecognised (a typo, a hand-edited document,
  /// a role we add in a future version), we fall back to [UserRole.member] —
  /// the least privileged role. Failing "closed" like this means a broken
  /// document can never accidentally hand someone leader powers.
  static UserRole fromName(String? value) => UserRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => UserRole.member,
  );

  /// Human-readable version for the UI. `name` gives the raw enum spelling,
  /// which is right for Firestore but wrong on screen.
  String get label => switch (this) {
    UserRole.member => 'Group Member',
    UserRole.leader => 'Group Leader',
    UserRole.coordinator => 'Module Coordinator',
  };
}

/// A Synca user, as stored in the `users` collection in Firestore.
///
/// This is our own model — deliberately separate from Firebase Auth's `User`
/// class. Firebase Auth only knows about credentials (uid, email); it has no
/// idea what a "group leader" is. [AppUser] is the app's view of a person.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.groupId = '',
  });

  /// Firebase Auth's unique id for this user. Also the Firestore document id,
  /// which is what lets us look a profile up directly instead of querying.
  final String uid;

  final String email;

  /// Display name the user typed at registration.
  final String name;

  final UserRole role;

  /// The group this user works in, or `''` if they haven't joined one yet.
  ///
  /// A member needs this to see which tasks are up for grabs. It defaults to
  /// empty rather than being required so existing documents — written before
  /// this field existed — still load, and so registration doesn't have to ask
  /// for a group before one exists.
  ///
  /// Deliberately a single id, not a list: for this coursework a student is in
  /// one group. If Synca ever needs multiple groups per person, this becomes a
  /// separate `memberships` collection rather than a longer string here.
  final String groupId;

  /// True once the user belongs to a group. Screens that need a group — the
  /// claim-a-task list, the group tab — check this before querying.
  bool get hasGroup => groupId.isNotEmpty;

  /// Converts this object into the plain `Map` that Firestore stores.
  ///
  /// Firestore cannot store a Dart object or an enum, only primitives (String,
  /// int, bool, List, Map, Timestamp...). So the enum is written as its name —
  /// `UserRole.leader` becomes the string `'leader'`.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role.name,
      'groupId': groupId,
    };
  }

  /// Builds an [AppUser] from a Firestore document's data.
  ///
  /// `factory` means this constructor doesn't have to create a brand new object
  /// the plain way — it runs code first, then returns an instance.
  ///
  /// Every field is read defensively. `map['email']` returns `dynamic`, so
  /// `as String?` says "treat it as a nullable String", and `?? ''` supplies a
  /// fallback if the field is missing or the wrong type. A half-written
  /// document should give us an empty name, not crash the app.
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      role: UserRole.fromName(map['role'] as String?),
      groupId: map['groupId'] as String? ?? '',
    );
  }

  @override
  String toString() => 'AppUser(uid: $uid, email: $email, role: ${role.name})';
}
