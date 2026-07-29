import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/member/model/group_member.dart';
import 'package:synca_app/src/modules/role/member/model/services/group_service.dart';

/// State and behaviour for the Group tab.
///
/// Membership itself is a single string on the user's own document, and only
/// the two actions here change it — so joining and leaving need no stream.
/// The **members list** does: people join and leave, and their task counts move
/// every time anybody in the group claims or finishes something.
///
/// Two subscriptions feed that list, and they are combined in memory:
///
/// - `/users` where `groupId` matches — who is in the group;
/// - `streamTasksForGroup` — every task in the group, counted by `ownerUid`.
///
/// Two streams rather than a count per member, which would be one query each
/// and would grow with the group. The task stream already exists, already has
/// its composite index, and a coursework group has tens of tasks — counting
/// them on the device is free next to the reads a per-member query would cost.
///
/// It keeps its own copy of [groupId] rather than reading `user.groupId` every
/// time. [AppUser] is immutable and was fetched once at sign-in, so it cannot
/// reflect a change made here. Keeping the current value locally is what lets
/// this screen update the instant a write succeeds — and what tells the streams
/// when to start over.
class GroupViewModel extends ChangeNotifier {
  GroupViewModel({
    required this.user,
    GroupService? groupService,
    TaskService? taskService,
  }) : _groupService = groupService ?? GroupService(),
       _taskService = taskService ?? TaskService(),
       _groupId = user.groupId {
    if (hasGroup) _subscribeToMembers();
  }

  final AppUser user;
  final GroupService _groupService;
  final TaskService _taskService;

  String _groupId;
  bool _isSubmitting = false;
  String? _errorMessage;

  StreamSubscription<List<GroupMember>>? _membersSubscription;
  StreamSubscription<List<Task>>? _tasksSubscription;

  List<GroupMember> _members = const [];

  /// How many tasks each uid owns. Rebuilt whole on every task snapshot rather
  /// than adjusted, so it cannot drift out of step with the tasks it came from.
  Map<String, int> _taskCounts = const {};

  bool _isLoadingMembers = false;
  String? _membersErrorMessage;

  /// The group the member is in, or `''` for none.
  String get groupId => _groupId;

  bool get hasGroup => _groupId.isNotEmpty;

  /// True while a join or leave is in flight. The page uses it to show a
  /// spinner and to disable the field and both buttons.
  bool get isSubmitting => _isSubmitting;

  String? get errorMessage => _errorMessage;

  /// True until the first batch of members arrives.
  bool get isLoadingMembers => _isLoadingMembers;

  /// Set when either stream fails. Kept apart from [errorMessage], which is
  /// about a join or leave that went wrong — the two appear in different places
  /// on the page and must not overwrite each other.
  String? get membersErrorMessage => _membersErrorMessage;

  /// The group, signed-in member first and everyone else by name.
  ///
  /// Built fresh on each read: the members from one stream, the counts from the
  /// other. Storing the combination would mean rebuilding it whenever either
  /// stream fired, and the day one of those is forgotten the counts sit against
  /// the wrong names.
  ///
  /// Yourself first because this list answers "how is my group doing" and you
  /// are the fixed point in that question. Firestore could not do this sort
  /// anyway — it depends on who is asking.
  List<GroupMember> get members {
    final combined = _members
        .map((member) => member.withTaskCount(_taskCounts[member.uid] ?? 0))
        .toList();

    return List.unmodifiable(
      GroupMember.sortedForViewer(combined, user.uid),
    );
  }

  /// Loaded fine, but nobody else has joined this code yet.
  ///
  /// One member means the signed-in user on their own — their own document
  /// always matches the query, so an empty list means the read has not landed
  /// rather than that the group is deserted.
  bool get isAloneInGroup =>
      !_isLoadingMembers && _membersErrorMessage == null && _members.length <= 1;

  /// Opens both streams for the current group.
  void _subscribeToMembers() {
    _isLoadingMembers = true;
    _membersErrorMessage = null;

    _membersSubscription = _groupService
        .streamMembers(_groupId)
        .listen(
          (members) {
            _members = members;
            _isLoadingMembers = false;
            _membersErrorMessage = null;
            notifyListeners();
          },
          onError: (Object error) {
            _isLoadingMembers = false;
            _membersErrorMessage = "Couldn't load your group members.";
            debugPrint('streamMembers failed: $error');
            notifyListeners();
          },
        );

    _tasksSubscription = _taskService
        .streamTasksForGroup(_groupId)
        .listen(
          (tasks) {
            final counts = <String, int>{};
            for (final task in tasks) {
              // Unclaimed tasks carry an empty ownerUid, which belongs to
              // nobody — counting it would invent a member.
              if (!task.isClaimed) continue;
              counts[task.ownerUid] = (counts[task.ownerUid] ?? 0) + 1;
            }
            _taskCounts = counts;
            notifyListeners();
          },
          // Deliberately quiet. The names are the point of this list; if only
          // the counts fail, showing everyone with zero is better than
          // replacing the whole list with an error.
          onError: (Object error) {
            debugPrint('streamTasksForGroup failed on the Group tab: $error');
          },
        );
  }

  /// Closes both streams and forgets what they delivered.
  ///
  /// Clearing the data matters as much as cancelling: a member who leaves and
  /// rejoins a different group would otherwise see the old group's people for a
  /// moment, before the new snapshot lands.
  void _unsubscribeFromMembers() {
    _membersSubscription?.cancel();
    _tasksSubscription?.cancel();
    _membersSubscription = null;
    _tasksSubscription = null;

    _members = const [];
    _taskCounts = const {};
    _isLoadingMembers = false;
    _membersErrorMessage = null;
  }

  /// Puts the member in a group.
  ///
  /// Returns the code actually stored on success, or null if it failed — the
  /// page needs that value to pass up to the dashboard, and a bool wouldn't
  /// carry it.
  ///
  /// The code is trimmed and upper-cased before it is written, so `group1`,
  /// `GROUP1 ` and ` Group1` all land on the same group. Without that,
  /// two members typing the same code with different capitalisation would end
  /// up in two different groups and never see each other's tasks — a bug that
  /// looks like a sync failure rather than a typo.
  Future<String?> join(String rawCode) async {
    final code = rawCode.trim().toUpperCase();

    // Validate before touching the network. An empty write would clear the
    // group, which is the opposite of what the button says it does.
    if (code.isEmpty) {
      _errorMessage = 'Enter your group code.';
      notifyListeners();
      return null;
    }

    return await _write(code) ? code : null;
  }

  /// Takes the member out of their group by clearing the field.
  Future<bool> leave() => _write('');

  /// The one place that writes, so the loading flag, the error handling and the
  /// local update can't drift between join and leave.
  Future<bool> _write(String groupId) async {
    if (_isSubmitting) return false;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _groupService.setGroupId(uid: user.uid, groupId: groupId);

      // Only updated after the write succeeds. Setting it first would show the
      // member as joined for a moment even if Firestore rejected it.
      _groupId = groupId;

      // Point the streams at the new group — or shut them down on the way out.
      // Leaving without this keeps a listener open on a group the member is no
      // longer in, which the rules would refuse on its next read anyway.
      _unsubscribeFromMembers();
      if (hasGroup) _subscribeToMembers();

      return true;
    } on FirebaseException catch (e) {
      _errorMessage = switch (e.code) {
        'permission-denied' =>
          "You don't have permission to change your group.",
        'not-found' => 'Your profile is missing. Please sign out and back in.',
        'unavailable' => 'No connection. Check your internet and try again.',
        _ => "Couldn't update your group. Please try again.",
      };
      debugPrint('setGroupId failed: [${e.code}] ${e.message}');
      return false;
    } catch (error) {
      _errorMessage = "Couldn't update your group. Please try again.";
      debugPrint('setGroupId failed: $error');
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Clears the error, so a stale message doesn't sit under the field while the
  /// member is typing a corrected code.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Cancels both streams. An uncancelled subscription keeps listening after
  /// the tab is gone — costing Firestore reads forever, and eventually trying
  /// to update a widget that no longer exists.
  @override
  void dispose() {
    _unsubscribeFromMembers();
    super.dispose();
  }
}
