import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/role/member/model/group_member.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/member_avatar.dart';

/// One person in the group list: avatar, name, role, and their workload.
///
/// Not tappable. A member cannot do anything to a group mate — reassigning work
/// is a leader's power — so a row that responded to touch would promise
/// something the app does not offer.
class GroupMemberRow extends StatelessWidget {
  const GroupMemberRow({
    super.key,
    required this.member,
    required this.isSignedInUser,
  });

  final GroupMember member;

  /// Marks this row as the person looking at the screen.
  final bool isSignedInUser;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // The same widget the Profile tab uses, so a member's chosen avatar
          // is the same picture wherever it appears — and falls back to their
          // initial in exactly the same way.
          MemberAvatar(
            avatarId: member.avatarId,
            name: member.name,
            radius: 20,
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Flexible, not Expanded: the name takes only what it needs
                    // so the "You" pill sits against it rather than being
                    // pushed to the far edge.
                    Flexible(
                      child: Text(
                        // A name could be empty on a half-written document.
                        member.name.isNotEmpty ? member.name : 'Unnamed member',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isSignedInUser) ...[
                      const SizedBox(width: 6),
                      const _YouPill(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  member.role.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.charcoal,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),
          _WorkloadLabel(taskCount: member.taskCount),
        ],
      ),
    );
  }
}

/// The small teal pill marking the signed-in member.
///
/// Shaped like `StatusChip` — the same pill, radius and weight, its colour at
/// 12% behind it — because it is the same kind of object: a small label
/// qualifying the thing beside it.
class _YouPill extends StatelessWidget {
  const _YouPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'You',
        style: TextStyle(
          color: AppColors.teal,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// How many tasks this person is carrying.
class _WorkloadLabel extends StatelessWidget {
  const _WorkloadLabel({required this.taskCount});

  final int taskCount;

  @override
  Widget build(BuildContext context) {
    // Spelled out rather than a bare number, because "0" beside a name reads as
    // a score. Nobody being idle is not a failing — a task list can simply be
    // fully claimed by other people.
    final label = switch (taskCount) {
      0 => 'No tasks',
      1 => '1 task',
      _ => '$taskCount tasks',
    };

    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        // The zero case is greyed back so a row with nothing on it does not
        // draw the eye more than the people actually carrying work.
        color: taskCount == 0
            ? AppColors.charcoal.withValues(alpha: 0.5)
            : AppColors.navy,
        fontWeight: taskCount == 0 ? FontWeight.normal : FontWeight.w600,
      ),
    );
  }
}
