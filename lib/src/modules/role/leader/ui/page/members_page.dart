import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/leader/ui/widget/leader_states.dart';
import 'package:synca_app/src/modules/role/leader/view_model/members_view_model.dart';

/// Members tab — everyone in the group and how many tasks they own.
class MembersPage extends StatefulWidget {
  const MembersPage({super.key, required this.user});

  final AppUser user;

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  late final MembersViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = MembersViewModel(user: widget.user);
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
        message: 'Link a group to your leader account to see members.',
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
            title: 'Could not load members',
            message: _viewModel.errorMessage!,
            onRetry: _viewModel.retry,
          );
        }

        if (_viewModel.isEmpty) {
          return const LeaderEmptyState(
            icon: Icons.person_outline,
            title: 'No members yet',
            message:
                'Nobody else is in this group.\n'
                'Share the group code so members can join.',
          );
        }

        final workloads = _viewModel.workloads;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: workloads.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final row = workloads[index];
            final initial = row.member.name.isNotEmpty
                ? row.member.name[0].toUpperCase()
                : '?';

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    child: Text(initial),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.member.name,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          row.member.role.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.charcoal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${row.ownedCount}',
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        row.ownedCount == 1 ? 'task' : 'tasks',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
