import 'package:flutter/material.dart';

import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/member/ui/page/task_detail_page.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/claim_task_sheet.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/empty_state.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/error_state.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/progress_card.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/task_actions.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/task_card.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/task_filter_chips.dart';
import 'package:synca_app/src/modules/role/member/view_model/my_tasks_view_model.dart';
import 'package:synca_app/src/modules/role/member/view_model/task_filter.dart';

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

  /// Tap a task → open its detail page.
  ///
  /// The row used to open the status sheet directly. It now opens the page, and
  /// the sheet lives behind a button there: a tap on a list row should show you
  /// the thing, not immediately ask you to change it.
  ///
  /// The route is handed the ViewModel and the task's **id**, never the [Task]
  /// itself — see the note on [TaskDetailPage] for why a snapshot would go
  /// stale. `MyTasksPage` stays mounted underneath, so the ViewModel it owns
  /// outlives the pushed route.
  void _openTaskDetail(Task task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailPage(viewModel: _viewModel, taskId: task.id),
      ),
    );
  }

  Future<void> _claimTask() async {
    final claimedTitle = await showClaimTaskSheet(
      context: context,
      user: widget.user,
    );

    if (!mounted || claimedTitle == null) return;

    // The shared styling from task_actions.dart, so every message this module
    // shows looks the same.
    showTaskSnackBar(context, 'Claimed "$claimedTitle"', isError: false);
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

            // Hidden while loading, on an error, and when the member owns
            // nothing at all. Five filter chips over an empty list would be
            // offering to narrow down nothing.
            if (!_viewModel.isLoading &&
                _viewModel.errorMessage == null &&
                !_viewModel.isEmpty) ...[
              TaskFilterChips(
                selected: _viewModel.filter,
                onSelected: _viewModel.setFilter,
              ),
              const SizedBox(height: 12),
            ],

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

  /// Picks one of five bodies. Order matters: loading is checked before error,
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

    // Two different nothings, and they say different things. This one is "you
    // have claimed nothing" — the wording comes from TaskFilter.all, which is
    // the original copy, kept there so both empty states live side by side.
    if (_viewModel.isEmpty) {
      return EmptyState(
        icon: Icons.task_alt,
        title: TaskFilter.all.emptyTitle,
        message: TaskFilter.all.emptyMessage,
      );
    }

    // And this one is "you have tasks, just none in this pile".
    if (_viewModel.hasNoMatches) {
      return EmptyState(
        // A filter, not a void: the icon says the list was narrowed rather than
        // that there is nothing to do.
        icon: Icons.filter_alt_outlined,
        title: _viewModel.filter.emptyTitle,
        message: _viewModel.filter.emptyMessage,
      );
    }

    final tasks = _viewModel.visibleTasks;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskCard(
          task: task,
          onTap: () => _openTaskDetail(task),
          // The proof link stays tappable on the row itself. Its own InkWell,
          // nested inside the card's, so tapping the link opens the link while
          // tapping anywhere else opens the detail page.
          onOpenProof: () => openProofLink(context, task),
        );
      },
    );
  }
}
