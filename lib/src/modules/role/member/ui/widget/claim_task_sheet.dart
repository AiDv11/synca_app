import 'package:flutter/material.dart';

import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/task_card.dart';
import 'package:synca_app/src/modules/role/member/view_model/claim_task_view_model.dart';

/// Slides up the group's unclaimed tasks so the member can take one.
///
/// Returns the title of the task they claimed, or null if they closed the sheet
/// without claiming. The caller uses the title for the confirmation message.
///
/// `isScrollControlled: true` lets the sheet grow past the default limit of
/// half the screen, and the height is then capped at 70% below. Without it a
/// list of ten tasks would be squashed into a very short scroll area.
Future<String?> showClaimTaskSheet({
  required BuildContext context,
  required AppUser user,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _ClaimTaskSheet(user: user),
  );
}

/// Stateful purely to own the ViewModel's lifecycle.
///
/// The rule: whoever creates a [ChangeNotifier] is responsible for disposing
/// it, and only a `State` object gets told when it's being removed. Creating
/// the ViewModel in `build` instead would spawn a new one — and a new Firestore
/// subscription — on every single rebuild.
class _ClaimTaskSheet extends StatefulWidget {
  const _ClaimTaskSheet({required this.user});

  final AppUser user;

  @override
  State<_ClaimTaskSheet> createState() => _ClaimTaskSheetState();
}

class _ClaimTaskSheetState extends State<_ClaimTaskSheet> {
  /// `late` means "no value yet, but never null once used". Needed because the
  /// ViewModel needs `widget.user`, which isn't available until initState.
  late final ClaimTaskViewModel _viewModel;

  /// Holds what the member types. The ViewModel owns the *query*; this owns the
  /// text field's own state — cursor position, selection — which is why both
  /// exist rather than one.
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = ClaimTaskViewModel(user: widget.user);
  }

  @override
  void dispose() {
    // Controllers hold resources that aren't freed automatically.
    _searchController.dispose();
    // Cancels the group query. Nothing else stops it.
    _viewModel.dispose();
    super.dispose();
  }

  /// Empties the search from the clear button.
  ///
  /// Both halves, and both are needed: the controller so the field goes blank,
  /// the ViewModel so the list widens again.
  void _clearSearch() {
    _searchController.clear();
    _viewModel.setQuery('');
  }

  Future<void> _claim(Task task) async {
    final error = await _viewModel.claim(task);

    // The claim is a network call, so time passed and the sheet may already be
    // gone. Using `context` after that throws — always re-check `mounted`.
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Success: close the sheet and hand the title back so the page underneath
    // can confirm it. The task also vanishes from My Tasks' opposite number —
    // the streams do that on their own.
    Navigator.of(context).pop(task.title);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Cap the height so the sheet never covers the whole screen — the member
      // should still see where they came from.
      height: MediaQuery.of(context).size.height * 0.7,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.charcoal.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.pan_tool_alt_outlined, color: AppColors.navy),
                  SizedBox(width: 8),
                  Text(
                    'Claim a task',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Unclaimed tasks in your group',
                  style: TextStyle(fontSize: 13, color: AppColors.charcoal),
                ),
              ),
            ),
            // ListenableBuilder subscribes to the ViewModel and rebuilds this
            // subtree whenever it calls notifyListeners(). Only what's inside
            // the builder rebuilds — the header above is untouched.
            //
            // The search field is inside it too, because whether to show the
            // field at all depends on ViewModel state.
            Expanded(
              child: ListenableBuilder(
                listenable: _viewModel,
                builder: (context, _) => Column(
                  children: [
                    _buildSearchField(),
                    const Divider(height: 1),
                    Expanded(child: _buildBody()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The search box, or nothing at all.
  ///
  /// Hidden when there is nothing to search: no group, still loading, the query
  /// failed, or the group has no spare tasks. A search field over an empty list
  /// invites the member to hunt for work that is not there.
  ///
  /// It deliberately stays put once a search matches nothing — that is exactly
  /// the moment they need to edit what they typed.
  Widget _buildSearchField() {
    if (_viewModel.hasNoGroup ||
        _viewModel.isLoading ||
        _viewModel.errorMessage != null ||
        _viewModel.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: TextField(
        controller: _searchController,
        // No autofocus: opening the sheet should show the tasks, not the
        // keyboard. The list is the point; searching is the exception.
        textInputAction: TextInputAction.search,
        // Straight through on every keystroke. No debounce — see setQuery.
        onChanged: _viewModel.setQuery,
        style: const TextStyle(color: AppColors.navy, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by title or description',
          prefixIcon: const Icon(Icons.search, color: AppColors.navy),
          // Only once there is something to clear, so the field is not
          // cluttered before it is used.
          suffixIcon: _viewModel.query.isEmpty
              ? null
              : IconButton(
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.close, color: AppColors.charcoal),
                  tooltip: 'Clear search',
                ),
          // The same treatment as the group code field and the proof link
          // field: filled with the light surface, no resting border, teal when
          // focused.
          filled: true,
          fillColor: AppColors.light,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.teal, width: 2),
          ),
          hintStyle: TextStyle(
            color: AppColors.charcoal.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.hasNoGroup) {
      return const _SheetMessage(
        icon: Icons.group_off_outlined,
        message:
            "You're not in a group yet.\n"
            'Your leader can add you to one.',
      );
    }

    if (_viewModel.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.teal),
      );
    }

    if (_viewModel.errorMessage != null) {
      return _SheetMessage(
        icon: Icons.cloud_off,
        message: _viewModel.errorMessage!,
      );
    }

    // Two different nothings. This one is "the group has no spare work".
    if (_viewModel.isEmpty) {
      return const _SheetMessage(
        icon: Icons.inbox_outlined,
        message:
            'No unclaimed tasks right now.\n'
            'Everything in your group has an owner.',
      );
    }

    // And this one is "there is spare work, but not by that name" — which is a
    // prompt to retype, not a reason to give up.
    if (_viewModel.hasNoMatches) {
      return _SheetMessage(
        icon: Icons.search_off,
        message:
            'Nothing matches "${_viewModel.query.trim()}".\n'
            'Try fewer words, or clear the search to see everything.',
      );
    }

    final tasks = _viewModel.visibleTasks;

    // ListView.builder only builds the rows actually on screen, rather than all
    // of them up front. Overkill for five tasks, but it's the habit to have.
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskCard(
          task: task,
          showStatus: false,
          // Passing null while a claim is running disables every row, so a
          // second tap can't start a second claim.
          onTap: _viewModel.isClaiming ? null : () => _claim(task),
          trailing: Icon(
            Icons.add_circle_outline,
            color: _viewModel.isClaiming
                ? AppColors.charcoal.withValues(alpha: 0.3)
                : AppColors.teal,
          ),
        );
      },
    );
  }
}

/// Centred icon-and-text block for the sheet's three empty states.
class _SheetMessage extends StatelessWidget {
  const _SheetMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.skyBlue),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.charcoal),
            ),
          ],
        ),
      ),
    );
  }
}
