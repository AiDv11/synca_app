import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/core/utils/deadline_format.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/leader/ui/widget/leader_states.dart';
import 'package:synca_app/src/modules/role/leader/ui/widget/status_chip.dart';
import 'package:synca_app/src/modules/role/leader/view_model/team_dashboard_view_model.dart';

/// Tasks tab — the full group task list with owner and due date.
///
/// Reuses [TeamDashboardViewModel] because it already streams every task in
/// the group. A dedicated ViewModel would only duplicate that subscription.
class LeaderTasksPage extends StatefulWidget {
  const LeaderTasksPage({super.key, required this.user});

  final AppUser user;

  @override
  State<LeaderTasksPage> createState() => _LeaderTasksPageState();
}

class _LeaderTasksPageState extends State<LeaderTasksPage> {
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

  @override
  Widget build(BuildContext context) {
    if (!widget.user.hasGroup) {
      return const LeaderEmptyState(
        icon: Icons.groups_outlined,
        title: 'No group yet',
        message: 'Link a group to your leader account to see its tasks.',
      );
    }

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        if (_viewModel.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.teal),
          );
        }

        if (_viewModel.errorMessage != null) {
          return LeaderErrorState(
            title: 'Could not load tasks',
            message: _viewModel.errorMessage!,
            onRetry: _viewModel.retry,
          );
        }

        if (_viewModel.isEmpty) {
          return const LeaderEmptyState(
            icon: Icons.checklist_outlined,
            title: 'No tasks yet',
            message: 'Add tasks from the Dashboard tab.',
          );
        }

        final tasks = _viewModel.tasks;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.isClaimed
                              ? task.ownerName
                              : 'Unassigned',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DeadlineFormat.relative(
                            task.deadline,
                            isDone: task.status.isDone,
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.charcoal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(status: task.status, compact: true),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
