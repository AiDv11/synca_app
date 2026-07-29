import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/leader/ui/widget/add_task_sheet.dart';
import 'package:synca_app/src/modules/role/leader/ui/widget/join_group_panel.dart';
import 'package:synca_app/src/modules/role/leader/ui/widget/leader_states.dart';
import 'package:synca_app/src/modules/role/leader/ui/widget/reassign_task_sheet.dart';
import 'package:synca_app/src/modules/role/leader/ui/widget/summary_card.dart';
import 'package:synca_app/src/modules/role/leader/ui/widget/task_overview_row.dart';
import 'package:synca_app/src/modules/role/leader/view_model/team_dashboard_view_model.dart';

/// Figure 3 — Team Dashboard content.
///
/// Three summary cards, the Task Overview list, and the two action buttons.
/// The bottom nav lives in [LeaderDashboard]; this page is only the body of
/// the Dashboard tab.
class TeamDashboardPage extends StatefulWidget {
  const TeamDashboardPage({
    super.key,
    required this.user,
    required this.onGroupChanged,
  });

  final AppUser user;

  /// Fired after the leader joins a group from the empty-state form.
  final ValueChanged<String> onGroupChanged;

  @override
  State<TeamDashboardPage> createState() => _TeamDashboardPageState();
}

class _TeamDashboardPageState extends State<TeamDashboardPage> {
  late final TeamDashboardViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = TeamDashboardViewModel(user: widget.user);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _addTask() async {
    final messenger = ScaffoldMessenger.of(context);
    final title = await showAddTaskSheet(
      context: context,
      user: widget.user,
      members: _viewModel.members,
    );
    if (!mounted || title == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Created "$title"'),
        backgroundColor: AppColors.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _reassignTask() async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await showReassignTaskSheet(
      context: context,
      user: widget.user,
    );
    if (!mounted || message == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.user.hasGroup) {
      return JoinGroupPanel(
        user: widget.user,
        onJoined: (code) {
          widget.onGroupChanged(code);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Joined $code'),
              backgroundColor: AppColors.teal,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    }

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  SummaryCard(
                    value: '${_viewModel.progressPercent}%',
                    label: 'progress',
                  ),
                  const SizedBox(width: 10),
                  SummaryCard(
                    value: '${_viewModel.atRiskCount}',
                    label: 'at risk',
                    emphasise: _viewModel.atRiskCount > 0,
                  ),
                  const SizedBox(width: 10),
                  SummaryCard(
                    value: '${_viewModel.memberCount}',
                    label: 'members',
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Task Overview',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            Expanded(child: _buildTaskList()),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _reassignTask,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.navy,
                        side: const BorderSide(color: AppColors.navy),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Reassign Task',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _addTask,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      // Exact wireframe copy, including the leading "+".
                      child: const Text(
                        '+ Add Task',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTaskList() {
    if (_viewModel.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.teal),
      );
    }

    if (_viewModel.errorMessage != null) {
      return LeaderErrorState(
        title: 'Could not load the dashboard',
        message: _viewModel.errorMessage!,
        onRetry: _viewModel.retry,
      );
    }

    if (_viewModel.isEmpty) {
      return const LeaderEmptyState(
        icon: Icons.task_alt,
        title: 'No tasks yet',
        message:
            'Create the first piece of work for your group.\n'
            'Tap "+ Add Task" below.',
      );
    }

    final tasks = _viewModel.tasks;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskOverviewRow(
          task: task,
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            final message = await showReassignTaskSheet(
              context: context,
              user: widget.user,
              initialTask: task,
            );
            if (!mounted || message == null) return;
            messenger.showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: AppColors.teal,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      },
    );
  }
}
