import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/leave_group_dialog.dart';
import 'package:synca_app/src/modules/role/member/view_model/group_view_model.dart';

/// The Group tab: join a group, or see the one you're in and leave it.
///
/// Two states, decided by whether the member has a group. Both live in one page
/// rather than two, because the member moves between them without navigating —
/// joining swaps the body in place.
class GroupPage extends StatefulWidget {
  const GroupPage({
    super.key,
    required this.user,
    required this.onGroupChanged,
  });

  final AppUser user;

  /// Reports a successful join or leave up to `MemberDashboard`, which holds
  /// the [AppUser] every other tab reads.
  ///
  /// This is the same "data down, events up" wiring as the View Timeline link.
  /// It matters more here: the claim sheet decides whether to query Firestore
  /// from `user.hasGroup`, so without this callback it would keep saying
  /// "you're not in a group" until the app restarted.
  final ValueChanged<String> onGroupChanged;

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  late final GroupViewModel _viewModel;

  /// Holds what the member types. Controllers own resources that aren't freed
  /// automatically, hence the `dispose` below.
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = GroupViewModel(user: widget.user);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = await _viewModel.join(_codeController.text);

    // Null means it failed; the ViewModel has already set an error message and
    // the page is showing it, so there is nothing more to do here.
    if (code == null || !mounted) return;

    _codeController.clear();
    widget.onGroupChanged(code);
    _showSnackBar('Joined $code', isError: false);
  }

  /// Confirms, then leaves the group.
  ///
  /// Leaving used to happen on the tap itself. It is not a small action — the
  /// whole board goes away the instant `groupId` is cleared, and getting back
  /// in needs the code, which the member may not have anywhere else. The
  /// confirmation is read before the code disappears from the screen.
  Future<void> _leave() async {
    // Captured before the dialog: after leaving, the ViewModel's groupId is
    // empty, and the dialog would have nothing to show.
    final groupId = _viewModel.groupId;

    final confirmed = await showLeaveGroupDialog(
      context: context,
      groupId: groupId,
    );

    // `!= true` rather than `== false`, because dismissing the dialog by
    // tapping outside it returns null. Only an explicit Leave goes on.
    if (!mounted || confirmed != true) return;

    final didLeave = await _viewModel.leave();
    if (!didLeave || !mounted) return;

    widget.onGroupChanged('');
    _showSnackBar('You have left the group', isError: false);
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _viewModel.hasGroup ? _buildJoined() : _buildJoinForm(),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // No group yet
  // ---------------------------------------------------------------------------

  Widget _buildJoinForm() {
    final isBusy = _viewModel.isSubmitting;

    return Column(
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
          'Join your group',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter the group code your group leader gave you. '
          'Once you join, you can claim tasks and see the group board.',
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
          // Codes are stored upper-case, so show them that way as they are
          // typed. The ViewModel upper-cases again before writing — this is
          // presentation, not validation, and must not be relied on.
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => isBusy ? null : _join(),
          // Any keystroke clears a stale error, so the message under the field
          // always refers to the code currently in it.
          onChanged: (_) => _viewModel.clearError(),
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
          decoration: InputDecoration(
            labelText: 'Group code',
            hintText: 'e.g. GROUP1',
            prefixIcon: const Icon(Icons.tag, color: AppColors.navy),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.teal, width: 2),
            ),
            labelStyle: const TextStyle(color: AppColors.charcoal),
          ),
        ),

        if (_viewModel.errorMessage != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: _viewModel.errorMessage!),
        ],

        const SizedBox(height: 20),

        FilledButton(
          // Null disables the button, which is the double-submit guard.
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
              // Sized explicitly, otherwise the spinner expands to the button's
              // full height and the button jumps.
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Join',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
        const SizedBox(height: 16),

        const Text(
          "Don't have a code? Ask your group leader — "
          'everyone in the group uses the same one.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.charcoal),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Already in a group
  // ---------------------------------------------------------------------------

  Widget _buildJoined() {
    final isBusy = _viewModel.isSubmitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Navy card, same treatment as the contribution card on My Tasks — it
        // is the one fact this screen exists to show.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text(
                'Your group',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _viewModel.groupId,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.teal,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Share this code so your group mates join the same board.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Honest about what this tab does and does not do yet.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                size: 20,
                color: AppColors.skyBlue,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Your group mates and their workload will appear here once '
                  'the group board is built.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.charcoal,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_viewModel.errorMessage != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: _viewModel.errorMessage!),
        ],

        const SizedBox(height: 24),

        OutlinedButton(
          onPressed: isBusy ? null : _leave,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: BorderSide(color: Colors.red.shade200),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isBusy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'Leave group',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
        ),
        const SizedBox(height: 10),

        const Text(
          'Leaving does not delete your tasks. You keep anything you have '
          'already claimed.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.charcoal),
        ),
      ],
    );
  }
}

/// Inline red panel for a failed write.
///
/// Inline rather than the full-screen `ErrorState`, because the screen itself
/// is fine — one action failed. Replacing the whole page would throw away the
/// code the member just typed.
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
          Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
