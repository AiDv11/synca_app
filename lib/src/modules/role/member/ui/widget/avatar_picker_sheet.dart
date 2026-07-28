import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/role/member/model/preset_avatar.dart';
import 'package:synca_app/src/modules/role/member/view_model/avatar_picker_view_model.dart';

/// Slides up the grid of preset avatars.
///
/// Returns true if the member picked a new one, null if they backed out by
/// swiping the sheet away. Callers must handle null; it means "do nothing" —
/// the same contract as the status picker and the change-password sheet.
///
/// [viewModel] is created and owned by the caller, not by this sheet, so the
/// choice outlives the sheet that made it. See [AvatarPickerViewModel].
Future<bool?> showAvatarPickerSheet({
  required BuildContext context,
  required AvatarPickerViewModel viewModel,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _AvatarPickerSheet(viewModel: viewModel),
  );
}

/// Stateful only to remember which circle was tapped.
///
/// The save itself lives in the ViewModel, but `isSaving` there is a plain bool
/// — it says *that* a write is running, not which of the twelve started it.
/// That one extra fact is what puts the spinner on the right circle, and it is
/// meaningless once the sheet closes, so it stays here rather than widening the
/// ViewModel.
class _AvatarPickerSheet extends StatefulWidget {
  const _AvatarPickerSheet({required this.viewModel});

  final AvatarPickerViewModel viewModel;

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  /// The avatar currently being written, or null when nothing is in flight.
  String? _savingId;

  // No dispose() for the ViewModel here on purpose — this sheet borrows it.
  // Disposing it would leave the Profile tab behind holding a dead object.

  /// One tap picks, saves and closes. There is no "Save" button.
  ///
  /// With twelve fixed options the choice is the whole interaction, so a second
  /// confirming tap would only add a step. The write is a single field on one
  /// document; if it fails the sheet stays open with the reason.
  Future<void> _select(PresetAvatar avatar) async {
    // Tapping the one they already have is a way of saying "this one is fine".
    // Close, but report no change, so the caller doesn't announce an update
    // that never happened.
    if (avatar.id == widget.viewModel.avatarId) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _savingId = avatar.id);

    final saved = await widget.viewModel.select(avatar.id);

    // An await happened, so the sheet may already be gone — the member can
    // swipe it away mid-write.
    if (!mounted) return;

    setState(() => _savingId = null);

    // On failure the ViewModel has set an error and the banner below is already
    // showing it, so there is nothing to do but stay open and let them retry.
    if (!saved) return;

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // ListenableBuilder rebuilds this subtree whenever the ViewModel calls
      // notifyListeners — that is how the error banner and the dimming appear
      // without this widget tracking them itself.
      child: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) => _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final isBusy = widget.viewModel.isSaving;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        // Hug the content instead of filling the screen.
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
              Icon(Icons.face_outlined, color: AppColors.navy),
              SizedBox(width: 8),
              Text(
                'Choose an avatar',
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
            'Pick one to show on your profile and next to your tasks.',
            style: TextStyle(fontSize: 13, color: AppColors.charcoal),
          ),
          const SizedBox(height: 20),

          // Two things at once while saving: IgnorePointer stops a second tap
          // reaching any circle, and the fade says why. The ViewModel guards
          // the double write as well — this is the visible half of that rule.
          IgnorePointer(
            ignoring: isBusy,
            child: AnimatedOpacity(
              opacity: isBusy ? 0.6 : 1,
              duration: const Duration(milliseconds: 150),
              child: _buildGrid(),
            ),
          ),

          if (widget.viewModel.errorMessage != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: widget.viewModel.errorMessage!),
          ],
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      // The grid sits inside a Column inside a scroll view, so it must measure
      // its own height (shrinkWrap) and leave scrolling to the parent —
      // two scrollables fighting over one drag is the usual cause of a grid
      // that won't move.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: PresetAvatars.all.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        // Four across turns the twelve into three tidy rows, and keeps each
        // circle comfortably above the ~48px minimum tap target on a phone.
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final avatar = PresetAvatars.all[index];

        return _AvatarOption(
          avatar: avatar,
          isSelected: avatar.id == widget.viewModel.avatarId,
          isSaving: avatar.id == _savingId,
          onTap: () => _select(avatar),
        );
      },
    );
  }
}

/// One tappable circle in the grid.
class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.avatar,
    required this.isSelected,
    required this.isSaving,
    required this.onTap,
  });

  final PresetAvatar avatar;

  /// The member's current avatar. Still tappable — the ViewModel skips the
  /// write when nothing changed, so disabling it would be a rule with no
  /// purpose.
  final bool isSelected;

  /// This particular circle is the one being written.
  final bool isSaving;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Material rather than a plain Container, because an ink splash is painted
    // onto the nearest Material *behind* the widget: a coloured Container over
    // an InkWell would hide its own ripple. Giving the circle its colour
    // through a Material puts the splash on top of that colour, where it can be
    // seen.
    return Material(
      color: avatar.background,
      // The teal ring marks the current choice. Drawn as the Material's own
      // border so it stays visible even on the teal backgrounds, where a tick
      // in brand colours would disappear.
      shape: CircleBorder(
        side: isSelected
            ? const BorderSide(color: AppColors.teal, width: 3)
            : BorderSide.none,
      ),
      // Keeps the ripple inside the circle instead of splashing a square.
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // A LayoutBuilder rather than a fixed icon size, because the grid
        // decides how wide these end up — four across on a narrow phone is a
        // good deal smaller than on a tablet.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = constraints.maxWidth;

            return Center(
              child: isSaving
                  ? SizedBox(
                      width: side * 0.35,
                      height: side * 0.35,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(avatar.icon, color: Colors.white, size: side * 0.5),
            );
          },
        ),
      ),
    );
  }
}

/// Inline red panel for a failed save.
///
/// Inline rather than replacing the sheet, so the grid stays on screen and the
/// member can simply tap again. Same treatment as the change-password sheet.
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
