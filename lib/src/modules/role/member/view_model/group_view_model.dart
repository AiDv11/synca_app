import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/member/model/services/group_service.dart';

/// State and behaviour for the Group tab.
///
/// Unlike the other member ViewModels this one holds **no stream**. Membership
/// is a single string on the user's own document, and nobody else changes it,
/// so there is nothing to listen to — the two actions here are the only things
/// that can alter it. That is why there is no `StreamSubscription` and no
/// `_subscribe`, and why `dispose` has nothing to cancel.
///
/// It does keep its own copy of [groupId] rather than reading `user.groupId`
/// every time. [AppUser] is immutable and was fetched once at sign-in, so it
/// cannot reflect a change made here. Keeping the current value locally is what
/// lets this screen update the instant a write succeeds.
class GroupViewModel extends ChangeNotifier {
  GroupViewModel({required this.user, GroupService? groupService})
    : _groupService = groupService ?? GroupService(),
      _groupId = user.groupId;

  final AppUser user;
  final GroupService _groupService;

  String _groupId;
  bool _isSubmitting = false;
  String? _errorMessage;

  /// The group the member is in, or `''` for none.
  String get groupId => _groupId;

  bool get hasGroup => _groupId.isNotEmpty;

  /// True while a join or leave is in flight. The page uses it to show a
  /// spinner and to disable the field and both buttons.
  bool get isSubmitting => _isSubmitting;

  String? get errorMessage => _errorMessage;

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
}
