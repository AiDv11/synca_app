import 'package:flutter/material.dart';

import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/core/utils/deadline_format.dart';
import 'package:synca_app/src/modules/role/member/model/proof_link.dart';
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
    this.onOpenProof,
    this.trailing,
    this.showStatus = true,
  });

  final Task task;

  /// Tapping the proof link. When null the link is not drawn at all, which is
  /// how the claim sheet keeps its rows to one purpose — an unclaimed task has
  /// no proof anyway.
  final VoidCallback? onOpenProof;

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

    // Pulled into a local so Dart's flow analysis promotes it from String? to
    // String inside the null check below — otherwise every use needs a `!`.
    final proofUrl = task.proofUrl;

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

                    // Only drawn when there is proof AND the caller wants it
                    // tappable. Its own InkWell, nested inside the card's, so a
                    // tap here opens the link instead of the status picker —
                    // the innermost gesture detector wins.
                    if (proofUrl != null && onOpenProof != null) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: onOpenProof,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.attach_file,
                                size: 13,
                                color: AppColors.teal,
                              ),
                              const SizedBox(width: 4),
                              // Flexible so a long host truncates rather than
                              // overflowing the card.
                              Flexible(
                                child: Text(
                                  'Proof · ${ProofLink.displayLabel(proofUrl)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.teal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.open_in_new,
                                size: 11,
                                color: AppColors.teal,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
