import 'package:flutter/material.dart';

import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/core/utils/deadline_format.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/status_chip.dart';

/// One task in a list: title, deadline and status chip, tappable.
///
/// The card doesn't know *what* tapping does — it just reports the tap through
/// [onTap]. On My Tasks that opens the status picker; in the claim sheet the
/// same card claims the task. A widget that decided for itself couldn't be used
/// in both places.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.trailing,
    this.showStatus = true,
  });

  final Task task;

  /// Null disables the tap and removes the ripple — how the claim sheet greys
  /// the list out while a claim is in flight.
  final VoidCallback? onTap;

  /// Replaces the status chip on the right, for the claim sheet's "+" button.
  final Widget? trailing;

  /// Unclaimed tasks are all `notStarted`, so the chip is noise there.
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final isOverdue = task.isOverdue;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        // InkWell draws the ripple that tells a user something is tappable.
        // It has to sit inside a Material to have a surface to paint on, and
        // the radius is repeated so the splash doesn't spill past the corners.
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Expanded makes this column take all the width the trailing
              // widget doesn't need. Without it, a long title would push the
              // chip off-screen and Flutter would paint an overflow warning.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      // Long titles end in "…" instead of wrapping forever.
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          isOverdue
                              ? Icons.error_outline
                              : Icons.schedule_outlined,
                          size: 14,
                          // Overdue work turns red — the one place the app goes
                          // outside the brand palette, because "late" has to
                          // read as a warning and no brand colour says that.
                          color: isOverdue
                              ? Colors.red.shade700
                              : AppColors.charcoal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DeadlineFormat.relative(task.deadline),
                          style: TextStyle(
                            fontSize: 12,
                            color: isOverdue
                                ? Colors.red.shade700
                                : AppColors.charcoal,
                            fontWeight: isOverdue
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // `??` picks the first non-null: a custom trailing widget if one
              // was given, otherwise the chip, otherwise nothing at all.
              trailing ??
                  (showStatus
                      ? StatusChip(status: task.status)
                      : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}
