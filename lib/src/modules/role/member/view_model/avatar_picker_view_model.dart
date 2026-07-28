import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:synca_app/src/modules/role/member/model/services/avatar_service.dart';

/// State and behaviour for the member's avatar: which one is chosen, and
/// changing it.
///
/// Owned by the Profile tab, not by the picker sheet. That split matters. The
/// sheet is opened and thrown away every time, but the chosen avatar has to
/// survive it — the profile circle keeps showing it after the sheet closes. So
/// the tab holds this object, hands it to the sheet, and both read the same
/// [avatarId].
///
/// The alternative — a ViewModel created inside the sheet that returns the new
/// id on the way out — means the tab needs its own copy of the value anyway,
/// and then there are two places storing the same thing.
///
/// One-shot reads and writes, so unlike `MyTasksViewModel` there is no stream
/// subscription and nothing to cancel.
class AvatarPickerViewModel extends ChangeNotifier {
  AvatarPickerViewModel({required this.uid, AvatarService? avatarService})
    : _avatarService = avatarService ?? AvatarService();

  final String uid;
  final AvatarService _avatarService;

  String? _avatarId;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  /// The member's chosen avatar id, or null if they have never picked one.
  ///
  /// Null is the normal starting state for every existing account, not a
  /// failure — the UI answers it with the initial-letter circle.
  String? get avatarId => _avatarId;

  /// True while [load] is in flight. The profile circle uses it to stay on the
  /// initial letter rather than flashing a wrong avatar and then correcting
  /// itself a moment later.
  bool get isLoading => _isLoading;

  /// True while a choice is being saved. The sheet dims the grid and ignores
  /// further taps, so an impatient double-tap can't fire two writes.
  bool get isSaving => _isSaving;

  /// Set only by [select]. A failed [load] leaves this null on purpose — see
  /// the comment there.
  String? get errorMessage => _errorMessage;

  /// Fetches the stored choice. Call once, when the Profile tab is created.
  ///
  /// A failure here is deliberately quiet: no message, no retry button. The
  /// screen has something true to fall back on — the initial-letter circle, the
  /// same thing shown to a member who has never picked an avatar — so an error
  /// banner over a decoration would be noise on a screen whose real job is the
  /// name, email and log-out button. The code still goes to the console.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    try {
      _avatarId = await _avatarService.fetchAvatarId(uid);
    } on FirebaseException catch (e) {
      debugPrint('fetchAvatarId failed: [${e.code}] ${e.message}');
    } catch (error) {
      debugPrint('fetchAvatarId failed: $error');
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  /// Saves the chosen avatar. Returns true if it was written.
  ///
  /// On success [avatarId] is updated here, so every widget listening to this
  /// object — the sheet's tick mark and the profile circle behind it — redraws
  /// from the same value.
  Future<bool> select(String avatarId) async {
    if (_isSaving) return false;

    // Nothing to write if the choice is the one already stored. The sheet
    // catches this first and closes without calling in; this is the safety net
    // for any future caller that doesn't.
    if (avatarId == _avatarId) return true;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _avatarService.setAvatarId(uid: uid, avatarId: avatarId);
      _avatarId = avatarId;
      return true;
    } on FirebaseException catch (e) {
      _errorMessage = switch (e.code) {
        'permission-denied' => "You don't have permission to change this.",
        'not-found' => 'Your profile is missing. Please sign out and back in.',
        'unavailable' => 'No connection. Check your internet and try again.',
        _ => "Couldn't save your avatar. Please try again.",
      };
      // Screen gets a sentence, console keeps the code — same split as the
      // rest of the module.
      debugPrint('setAvatarId failed: [${e.code}] ${e.message}');
      return false;
    } catch (error) {
      _errorMessage = "Couldn't save your avatar. Please try again.";
      debugPrint('setAvatarId failed: $error');
      return false;
    } finally {
      _isSaving = false;
      _safeNotify();
    }
  }

  /// Notifies only if this object is still alive.
  ///
  /// Both methods above await the network, and the member can leave the Profile
  /// tab — or sign out — while one is running, which disposes this ViewModel.
  /// Calling [notifyListeners] on a disposed [ChangeNotifier] throws.
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
