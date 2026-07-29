import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/leader/model/services/group_membership_service.dart';

/// Join-group form for leaders who registered without a groupId.
class JoinGroupViewModel extends ChangeNotifier {
  JoinGroupViewModel({
    required this.user,
    GroupMembershipService? membershipService,
  }) : _membershipService = membershipService ?? GroupMembershipService();

  final AppUser user;
  final GroupMembershipService _membershipService;

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Trims + upper-cases the code, writes it, returns the stored code or null.
  Future<String?> join(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      _errorMessage = 'Enter your group code.';
      notifyListeners();
      return null;
    }

    if (_isSubmitting) return null;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _membershipService.setGroupId(uid: user.uid, groupId: code);
      return code;
    } on FirebaseException catch (e) {
      _errorMessage = switch (e.code) {
        'permission-denied' =>
          "You don't have permission to change your group.",
        'not-found' => 'Your profile is missing. Please sign out and back in.',
        'unavailable' => 'No connection. Check your internet and try again.',
        _ => "Couldn't update your group. Please try again.",
      };
      debugPrint('leader setGroupId failed: [${e.code}] ${e.message}');
      return null;
    } catch (error) {
      _errorMessage = "Couldn't update your group. Please try again.";
      debugPrint('leader setGroupId failed: $error');
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
