import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';

/// One person on the Group tab: who they are, and how much they are carrying.
///
/// Not [AppUser], for two reasons. `AppUser` has no `avatarId` — that field
/// sits on the user document but was never added to the model, which is why
/// `AvatarService` exists — and it has no room for a task count, which is not
/// stored anywhere at all. It is counted here from the group's tasks.
///
/// So this is a view of a person *for this screen*: the fields the members list
/// draws, and nothing else. It deliberately carries no email — the list has no
/// reason to show one, and not reading it is one less thing to leak.
class GroupMember {
  const GroupMember({
    required this.uid,
    required this.name,
    required this.role,
    this.avatarId,
    this.taskCount = 0,
  });

  final String uid;
  final String name;
  final UserRole role;

  /// The preset avatar they chose, or null if they never did. Passed straight
  /// to `MemberAvatar`, which falls back to their initial.
  final String? avatarId;

  /// How many of the group's tasks this person currently owns.
  ///
  /// Zero by default because it is **not** in the user document — it is counted
  /// from the task stream after the fact. A member read straight from Firestore
  /// always starts at zero and is given its real count by [withTaskCount].
  final int taskCount;

  /// A copy of this member carrying [count].
  ///
  /// The class is immutable, so combining the two streams means building new
  /// objects rather than mutating these. That is what keeps a half-updated
  /// member — new count, stale name — from ever existing.
  GroupMember withTaskCount(int count) => GroupMember(
    uid: uid,
    name: name,
    role: role,
    avatarId: avatarId,
    taskCount: count,
  );

  /// [members] with [viewerUid] first, then everyone else by name.
  ///
  /// A pure function on the model rather than a comparator buried in the
  /// ViewModel, and deliberately so: this is the rule the Group tab is judged
  /// on, and the ViewModel cannot be built in a test — its services reach
  /// `FirebaseFirestore.instance` in their constructors. Out here it can be.
  ///
  /// Yourself first because the list answers "how is my group doing", and you
  /// are the fixed point in that question. Firestore could not sort this way in
  /// any case: the order depends on who is asking.
  ///
  /// Sorts a copy — `List.sort` mutates in place, and quietly reordering the
  /// caller's list is how a stream's own buffer ends up scrambled.
  static List<GroupMember> sortedForViewer(
    List<GroupMember> members,
    String viewerUid,
  ) {
    final sorted = [...members];

    sorted.sort((a, b) {
      if (a.uid == viewerUid) return -1;
      if (b.uid == viewerUid) return 1;
      // Case-insensitive, so "ali" and "Ali" do not fall into separate blocks.
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return sorted;
  }

  /// Builds a member from a `/users` document.
  ///
  /// [uid] comes from the document id rather than the `uid` field. Both should
  /// agree — the security rules force it at creation — but the id is the one
  /// Firestore guarantees, and tasks are matched against it.
  ///
  /// Every field is read defensively, the same way `AppUser.fromMap` does: a
  /// half-written document should give an empty name, not crash the tab.
  factory GroupMember.fromMap(Map<String, dynamic> map, {required String uid}) {
    return GroupMember(
      uid: uid,
      name: map['name'] as String? ?? '',
      role: UserRole.fromName(map['role'] as String?),
      avatarId: map['avatarId'] as String?,
    );
  }
}
