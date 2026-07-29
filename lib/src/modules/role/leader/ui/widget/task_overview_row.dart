import 'package:flutter/material.dart';

import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/core/utils/deadline_format.dart';
import 'package:synca_app/src/modules/role/leader/ui/widget/status_chip.dart';
import 'package:synca_app/src/modules/role/leader/view_model/at_risk.dart';

/// One row in the Team Dashboard's "Task Overview" list.
///
/// Layout matches Figure 3: title + status chip on the first line, then
/// `"owner - status detail"` underneath. At-risk rows get a danger tint and
/// a thin left border so they stand out without relying on colour alone.
class TaskOverviewRow extends StatelessWidget {
  const TaskOverviewRow({
    super.key,
    required this.task,
    this.onTap,
  });

  final Task task;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final atRisk = AtRisk.isAtRisk(task);
    final ownerLabel = task.isClaimed ? task.ownerName : 'Unassigned';
    final detail = atRisk
        ? AtRisk.reason(task)
        : DeadlineFormat.relative(
            task.deadline,
            isDone: task.status.isDone,
          );

    return Material(
      color: atRisk
          ? AppColors.danger.withValues(alpha: 0.06)
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: atRisk
                ? const Border(
                    left: BorderSide(color: AppColors.danger, width: 4),
                  )
                : null,
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
                      '$ownerLabel — $detail',
                      style: TextStyle(
                        fontSize: 13,
                        color: atRisk
                            ? AppColors.danger
                            : AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusChip(status: task.status, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}
