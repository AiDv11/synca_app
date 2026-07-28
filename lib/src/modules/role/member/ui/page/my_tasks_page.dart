import 'package:flutter/material.dart';

import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/member/model/proof_link.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/claim_task_sheet.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/empty_state.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/error_state.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/progress_card.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/status_picker_sheet.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/task_card.dart';
import 'package:synca_app/src/modules/role/member/view_model/my_tasks_view_model.dart';

/// The Tasks tab: my progress, my claimed tasks, and a way to claim more.
///
/// This is the **View** in MVVM, and it is deliberately thin. It builds
/// widgets, forwards taps to [MyTasksViewModel], and shows what the ViewModel
/// reports. There is no Firestore import here, no query, and no business rule —
/// per CLAUDE.md, if a widget file imports `cloud_firestore`, something is in
/// the wrong layer. (The `task_service` import below is for the `Task` *type*
/// only; the widget never calls the service.)
class MyTasksPage extends StatefulWidget {
  const MyTasksPage({
    super.key,
    required this.user,
    required this.onViewTimeline,
  });

  final AppUser user;

  /// Called by the contribution card's "View Timeline" link.
  ///
  /// The page cannot switch tabs itself — the selected tab belongs to
  /// `MemberDashboard`, which owns the bottom nav. So the shell passes a
  /// callback down and this page just reports that the link was tapped.
  ///
  /// This is the standard Flutter pattern: **data flows down, events flow up.**
  /// A child never reaches up into its parent's state; it is handed a function
  /// to call, and the parent decides what that means.
  final VoidCallback onViewTimeline;

  @override
  State<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends State<MyTasksPage> {
  late final MyTasksViewModel _viewModel;

  /// Created once here, not in `build`. `build` runs on every frame that
  /// touches this widget; creating the ViewModel there would open a new
  /// Firestore stream each time and throw the old data away.
  @override
  void initState() {
    super.initState();
    _viewModel = MyTasksViewModel(user: widget.user);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// Tap a task → pick a status, and a proof link if it asks for one → write it.
  Future<void> _changeStatus(Task task) async {
    final choice = await showStatusPicker(context: context, task: task);

    // Null means they swiped the sheet away without choosing.
    if (choice == null) return;

    final error = await _viewModel.changeStatus(
      task,
      choice.status,
      proofUrl: choice.proofUrl,
    );

    // Two awaits have happened, so the screen may be gone. `mounted` is a
    // property of State that flips to false once the widget is removed.
    if (!mounted) return;

    if (error != null) {
      _showSnackBar(error);
      return;
    }

    // No setState and no manual list update. The write went to Firestore,
    // Firestore pushed it back down the stream, the ViewModel notified, and the
    // list has already redrawn itself by the time this line runs.
    _showSnackBar(
      choice.proofUrl != null
          ? 'Moved to ${choice.status.label}, proof attached'
          : 'Moved to ${choice.status.label}',
      isError: false,
    );
  }

  /// Opens a task's proof link in the browser.
  Future<void> _openProof(Task task) async {
    final url = task.proofUrl;
    if (url == null) return;

    final opened = await ProofLink.open(url);

    if (!mounted || opened) return;

    // False means nothing on the device could handle the link — a malformed
    // URL, or no browser installed. Worth saying rather than appearing to do
    // nothing at all when the member taps.
    _showSnackBar("Couldn't open that link.");
  }

  Future<void> _claimTask() async {
    final claimedTitle = await showClaimTaskSheet(
      context: context,
      user: widget.user,
    );

    if (!mounted || claimedTitle == null) return;

    _showSnackBar('Claimed "$claimedTitle"', isError: false);
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : AppColors.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder is the bridge between ViewModel and View. It listens to
    // the ViewModel and re-runs its builder on every notifyListeners(). This is
    // what a package like Provider does underneath — Flutter just gives it to
    // us for free.
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        // The order here is fixed by Figure 2 in CLAUDE.md: contribution card,
        // then the "My Claimed Tasks" heading, then the list, then the claim
        // button underneath it.
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: ProgressCard(
                completedCount: _viewModel.completedCount,
                totalCount: _viewModel.totalCount,
                progress: _viewModel.progress,
                onViewTimeline: widget.onViewTimeline,
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'My Claimed Tasks',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Expanded gives the list all the leftover vertical space. A
            // ListView inside a Column without it throws an unbounded-height
            // error — one of the first Flutter errors everyone meets.
            //
            // Only this middle section scrolls. The card above and the button
            // below stay put, so claiming a task never means scrolling to the
            // bottom of a long list to find the button.
            Expanded(child: _buildTaskList()),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _claimTask,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.teal,
                    side: const BorderSide(color: AppColors.teal),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  // The label carries its own "+" because that is the wording
                  // in the wireframe. An icon widget would render a plus too,
                  // but the approved copy is the literal string.
                  child: const Text(
                    '+ Claim a Task',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Picks one of four bodies. Order matters: loading is checked before error,
  /// error before empty, and the real list last.
  Widget _buildTaskList() {
    if (_viewModel.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.teal),
      );
    }

    if (_viewModel.errorMessage != null) {
      return ErrorState(
        title: 'Could not load your tasks',
        message: _viewModel.errorMessage!,
        onRetry: _viewModel.retry,
      );
    }

    if (_viewModel.isEmpty) {
      return const EmptyState(
        icon: Icons.task_alt,
        title: 'No tasks yet',
        message:
            "You haven't claimed anything.\n"
            'Tap "Claim a Task" to pick one up.',
      );
    }

    final tasks = _viewModel.tasks;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskCard(
          task: task,
          onTap: () => _changeStatus(task),
          onOpenProof: () => _openProof(task),
        );
      },
    );
  }
}
