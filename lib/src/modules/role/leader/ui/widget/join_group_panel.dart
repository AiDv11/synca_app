import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/leader/view_model/join_group_view_model.dart';

/// Join / create a group by code — shown when the leader has no groupId yet.
///
/// Returns the joined code via [onJoined] so the shell can update [AppUser]
/// without restarting the app.
class JoinGroupPanel extends StatefulWidget {
  const JoinGroupPanel({
    super.key,
    required this.user,
    required this.onJoined,
  });

  final AppUser user;
  final ValueChanged<String> onJoined;

  @override
  State<JoinGroupPanel> createState() => _JoinGroupPanelState();
}

class _JoinGroupPanelState extends State<JoinGroupPanel> {
  late final JoinGroupViewModel _viewModel;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = JoinGroupViewModel(user: widget.user);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = await _viewModel.join(_codeController.text);
    if (code == null || !mounted) return;
    widget.onJoined(code);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final isBusy = _viewModel.isSubmitting;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Icon(
                Icons.group_add_outlined,
                size: 52,
                color: AppColors.skyBlue,
              ),
              const SizedBox(height: 16),
              const Text(
                'Join or create your group',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter a group code. If your teammates already use one, '
                'type that. If you are starting fresh, invent a code '
                '(e.g. GROUP17) and share it with members.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.charcoal,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                enabled: !isBusy,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => isBusy ? null : _join(),
                onChanged: (_) => _viewModel.clearError(),
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
                decoration: InputDecoration(
                  labelText: 'Group code',
                  hintText: 'e.g. GROUP17',
                  prefixIcon: const Icon(Icons.tag, color: AppColors.navy),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.teal,
                      width: 2,
                    ),
                  ),
                ),
              ),
              if (_viewModel.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _viewModel.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: isBusy ? null : _join,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isBusy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
