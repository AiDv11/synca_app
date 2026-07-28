import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/core/utils/validators.dart';
import 'package:synca_app/src/modules/role/member/view_model/change_password_view_model.dart';

/// Slides up the change-password form.
///
/// Returns true if the password was changed, null if the member backed out.
/// The caller uses that to decide whether to confirm.
///
/// `isScrollControlled` plus the `viewInsets` padding inside is what lets the
/// sheet rise above the keyboard — with three password fields there is no room
/// to type otherwise.
Future<bool?> showChangePasswordSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _ChangePasswordSheet(),
  );
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  late final ChangePasswordViewModel _viewModel;

  /// Handle to the form. `validate()` runs every field's validator at once and
  /// returns true only if all pass.
  final _formKey = GlobalKey<FormState>();

  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  /// Separate toggles: revealing the new password and its confirmation
  /// together is normal, but the current one is a different secret and there
  /// is no reason to expose all three at once.
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  @override
  void initState() {
    super.initState();
    _viewModel = ChangePasswordViewModel();
  }

  @override
  void dispose() {
    // Controllers hold resources that aren't freed automatically. Forgetting
    // this leaks memory every time the sheet is opened.
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Local rules first — length and matching are decided on the device, so a
    // typo never costs a network round trip.
    if (!_formKey.currentState!.validate()) return;

    final succeeded = await _viewModel.submit(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );

    // An await happened, so the sheet may already be gone.
    if (!mounted || !succeeded) return;

    // On failure the ViewModel has set an error and the banner is already
    // showing it, so there is nothing to do but stay open.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the sheet by exactly the keyboard's height.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final isBusy = _viewModel.isSubmitting;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The grab handle every sheet in this app has.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const Row(
              children: [
                Icon(Icons.lock_outline, color: AppColors.navy),
                SizedBox(width: 8),
                Text(
                  'Change password',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter your current password, then choose a new one.',
              style: TextStyle(fontSize: 13, color: AppColors.charcoal),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _currentController,
              obscureText: _obscureCurrent,
              enabled: !isBusy,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _viewModel.clearError(),
              decoration: _decoration(
                label: 'Current password',
                suffix: _visibilityToggle(
                  isObscured: _obscureCurrent,
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
              // Only "not empty" here. A length rule would be wrong: an old
              // account might predate the six-character minimum, and rejecting
              // a valid password locally would lock them out of this screen.
              validator: (value) =>
                  Validators.required(value, 'Current password'),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _newController,
              obscureText: _obscureNew,
              enabled: !isBusy,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _viewModel.clearError(),
              decoration: _decoration(
                label: 'New password',
                suffix: _visibilityToggle(
                  isObscured: _obscureNew,
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              // The shared rule from core/utils: not empty, at least six
              // characters. Firebase enforces the same minimum, but only after
              // a round trip and with a worse message.
              validator: Validators.password,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _confirmController,
              obscureText: _obscureNew,
              enabled: !isBusy,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => isBusy ? null : _submit(),
              onChanged: (_) => _viewModel.clearError(),
              decoration: _decoration(label: 'Confirm new password'),
              // Written inline rather than added to Validators, because it is
              // the only rule in the app that compares two fields — it needs
              // the other controller, which a shared static function has no
              // way to reach.
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirm your new password';
                }
                if (value != _newController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),

            if (_viewModel.errorMessage != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(message: _viewModel.errorMessage!),
            ],

            const SizedBox(height: 24),

            FilledButton(
              // A null callback disables the button, which is the
              // double-submit guard.
              onPressed: isBusy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isBusy
                  // Sized explicitly, otherwise the spinner expands to the
                  // button's full height and the button jumps.
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Update password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// The eye button that reveals a password field.
  Widget _visibilityToggle({
    required bool isObscured,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: AppColors.charcoal,
      ),
    );
  }

  /// Shared field styling, matching the login and register pages.
  InputDecoration _decoration({required String label, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.navy),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.light,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.teal, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.charcoal),
    );
  }
}

/// Inline red panel for a failed attempt.
///
/// Inline rather than replacing the sheet, so the member keeps what they typed
/// and can correct one field. Same treatment as the Group tab uses.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
