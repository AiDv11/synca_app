import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:synca_app/src/modules/common/auth/model/services/auth_service.dart';

/// State and behaviour for the change-password sheet.
///
/// No stream — this is a one-shot action, so the only state is "is it running"
/// and "did it fail". Same shape as `GroupViewModel`, which is the other
/// write-only screen in this module.
class ChangePasswordViewModel extends ChangeNotifier {
  ChangePasswordViewModel({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  bool _isSubmitting = false;
  String? _errorMessage;

  /// True while the change is in flight. The sheet uses it to disable every
  /// field and show a spinner in the button.
  bool get isSubmitting => _isSubmitting;

  String? get errorMessage => _errorMessage;

  /// Attempts the change. True on success.
  ///
  /// Returns a bool rather than storing a "done" flag because the sheet closes
  /// on success — there is no state left to report to.
  Future<bool> submit({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_isSubmitting) return false;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _messageFor(e.code);
      // The screen gets a sentence; the console keeps the code, same split as
      // the task and timeline screens.
      debugPrint('changePassword failed: [${e.code}] ${e.message}');
      return false;
    } catch (error) {
      _errorMessage = "Couldn't change your password. Please try again.";
      debugPrint('changePassword failed: $error');
      return false;
    } finally {
      _isSubmitting = false;
      _safeNotify();
    }
  }

  /// Turns a Firebase code into something the member can act on.
  ///
  /// Every branch says what to *do*, not what went wrong internally. No code
  /// reaches the screen.
  String _messageFor(String code) => switch (code) {
    // Recent Firebase versions return the vaguer 'invalid-credential' where
    // older ones returned 'wrong-password'. Both mean the same thing here,
    // because the only credential being checked is the current password.
    'wrong-password' ||
    'invalid-credential' => 'Your current password is incorrect.',

    'weak-password' => 'That password is too weak. Use at least 6 characters.',

    // Should be unreachable — the service reauthenticates and retries — but if
    // it does surface, signing out and back in is the way through.
    'requires-recent-login' =>
      'For security, please sign out and back in, then try again.',

    'too-many-requests' => 'Too many attempts. Try again in a few minutes.',

    'network-request-failed' =>
      'No internet connection. Check your network and try again.',

    'no-current-user' ||
    'no-email' => 'You need to be signed in to change your password.',

    _ => "Couldn't change your password. Please try again.",
  };

  /// Clears a stale error while the member is correcting a field.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Notifies only if this object is still alive.
  ///
  /// [submit] has an `await` in it and the member can swipe the sheet away
  /// mid-flight, which disposes this ViewModel. A plain [notifyListeners] on a
  /// disposed [ChangeNotifier] throws — this is the ViewModel equivalent of a
  /// widget's `if (!mounted) return`.
  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
