import 'package:flutter_test/flutter_test.dart';

import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/member/model/group_member.dart';

/// Tests for the Group tab's member model.
///
/// `GroupViewModel` cannot be built in a test — both `GroupService` and
/// `TaskService` reach `FirebaseFirestore.instance` in their constructors — so
/// the parts worth pinning were kept out here as pure functions. This covers
/// the ordering rule and the defensive parsing; the streams and the counting
/// remain untested.
void main() {
  GroupMember member(String uid, String name) =>
      GroupMember(uid: uid, name: name, role: UserRole.member);

  group('sortedForViewer', () {
    test('puts the signed-in member first, whatever their name', () {
      final members = [
        member('u_amy', 'Amy'),
        member('u_zoe', 'Zoe'),
        member('u_me', 'Sam'),
      ];

      final sorted = GroupMember.sortedForViewer(members, 'u_me');

      expect(sorted.first.uid, 'u_me');
      // Even when the viewer's name would sort last.
      final lastByName = GroupMember.sortedForViewer([
        member('u_amy', 'Amy'),
        member('u_me', 'Zoe'),
      ], 'u_me');
      expect(lastByName.first.uid, 'u_me');
    });

    test('sorts everyone else by name, ignoring case', () {
      final members = [
        member('u3', 'charlie'),
        member('u1', 'Bea'),
        member('u2', 'alice'),
        member('u_me', 'Sam'),
      ];

      final sorted = GroupMember.sortedForViewer(members, 'u_me');

      expect(sorted.map((m) => m.name), ['Sam', 'alice', 'Bea', 'charlie']);
    });

    test('does not reorder the caller\'s list', () {
      // The ViewModel hands in a list built from a stream. Sorting in place
      // would scramble something it does not own.
      final original = [member('u_zoe', 'Zoe'), member('u_me', 'Sam')];
      final before = original.map((m) => m.uid).toList();

      GroupMember.sortedForViewer(original, 'u_me');

      expect(original.map((m) => m.uid).toList(), before);
    });

    test('copes with a viewer who is not in the list', () {
      // Possible for a moment after leaving, before the stream catches up.
      final sorted = GroupMember.sortedForViewer([
        member('u_zoe', 'Zoe'),
        member('u_amy', 'Amy'),
      ], 'u_nobody');

      expect(sorted.map((m) => m.name), ['Amy', 'Zoe']);
    });
  });

  group('fromMap', () {
    test('reads a complete document', () {
      final parsed = GroupMember.fromMap({
        'name': 'Ali',
        'role': 'leader',
        'avatarId': 'avatar_03',
      }, uid: 'u1');

      expect(parsed.uid, 'u1');
      expect(parsed.name, 'Ali');
      expect(parsed.role, UserRole.leader);
      expect(parsed.avatarId, 'avatar_03');
      // Never stored — it is counted from the task stream afterwards.
      expect(parsed.taskCount, 0);
    });

    test('survives a half-written document', () {
      final parsed = GroupMember.fromMap({}, uid: 'u1');

      expect(parsed.name, '');
      // Unknown or missing roles fall back to the least privileged one.
      expect(parsed.role, UserRole.member);
      expect(parsed.avatarId, isNull);
    });

    test('takes the uid from the document id, not the field', () {
      // They should agree — the create rule forces it — but the id is the one
      // Firestore guarantees, and tasks match against it.
      final parsed = GroupMember.fromMap({
        'uid': 'stale_value',
        'name': 'Ali',
      }, uid: 'real_id');

      expect(parsed.uid, 'real_id');
    });
  });

  test('withTaskCount changes only the count', () {
    const original = GroupMember(
      uid: 'u1',
      name: 'Ali',
      role: UserRole.leader,
      avatarId: 'avatar_03',
    );

    final counted = original.withTaskCount(4);

    expect(counted.taskCount, 4);
    expect(counted.uid, original.uid);
    expect(counted.name, original.name);
    expect(counted.role, original.role);
    expect(counted.avatarId, original.avatarId);
    // The original is untouched — combining the two streams builds new objects
    // rather than mutating these.
    expect(original.taskCount, 0);
  });
}
