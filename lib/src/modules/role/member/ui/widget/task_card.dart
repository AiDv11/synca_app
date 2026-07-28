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

  /// The faintest wash of [AppColors.danger] over the card's white.
  ///
  /// Kept this weak on purpose. The border and the label are what carry the
  /// message; if the fill were strong enough to notice on its own, a list with
  /// several late tasks would look alarming rather than informative, and the
  /// navy title would start to lose contrast against it.
  static const Color _overdueSurface = Color(0xFFFEF4F4);

  @override
  Widget build(BuildContext context) {
    // Asked of DeadlineFormat rather than read off `task.isOverdue`, and the
    // difference matters. The model's getter compares exact instants, so a task
    // due at 9am today is "overdue" by 10am; DeadlineFormat compares whole
    // days, which is what the countdown text below is built from. Using both
    // would let a card show a red border while its own text said "Due today".
    final isOverdue = DeadlineFormat.isOverdue(
      task.deadline,
      isDone: task.status.isDone,
    );

    // Null unless there is a real link. `ProofLink.hasProof` is the one place
    // that knows removed proof is stored as an empty string, and collapsing
    // both "no proof" cases to null here means the check below is a plain null
    // test — which Dart's flow analysis can see through, promoting this from
    // String? to String so the uses inside need no `!`.
    final proofUrl = ProofLink.hasProof(task.proofUrl) ? task.proofUrl : null;

    return Material(
      // A tint and an outline rather than a redesign: the card keeps its shape
      // and its contents stay exactly where they were, so a list of tasks still
      // scans as one list with some of its rows raising a hand.
      color: isOverdue ? _overdueSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        // `shape` replaces the old `borderRadius:` argument — Material accepts
        // one or the other, and only `shape` can carry a border.
        side: isOverdue
            ? const BorderSide(color: AppColors.danger, width: 1.5)
            : BorderSide.none,
      ),
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
                    Row(
                      // Top-aligned, because a title running to two lines would
                      // otherwise drag the label down to sit beside the second.
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Expanded, not Flexible: the title keeps the whole
                        // width when there is no label beside it, so a card
                        // that isn't overdue looks exactly as it did before.
                        Expanded(
                          child: Text(
                            task.title,
                            maxLines: 2,
                            // Long titles end in "…" instead of wrapping
                            // forever.
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isOverdue) ...[
                          const SizedBox(width: 8),
                          const _OverdueLabel(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          isOverdue
                              ? Icons.error_outline
                              : Icons.schedule_outlined,
                          size: 14,
                          color: isOverdue
                              ? AppColors.danger
                              : AppColors.charcoal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          // `isDone` is passed so a finished task shows its
                          // plain date instead of counting down work that is
                          // already over.
                          DeadlineFormat.relative(
                            task.deadline,
                            isDone: task.status.isDone,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: isOverdue
                                ? AppColors.danger
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

/// The small red "Overdue" badge beside the title.
///
/// It says the same thing as the red text below it ("2 days overdue"), and that
/// repetition is deliberate rather than sloppy. The two are read at different
/// speeds: a badge is caught while scanning a list of cards, the sentence
/// underneath is read only once a card has your attention, and it is the half
/// that says *how* late. Colour alone would carry neither to anyone who cannot
/// separate red from grey.
class _OverdueLabel extends StatelessWidget {
  const _OverdueLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Overdue',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          // Small uppercase-weight text set solid reads as a smudge; a little
          // tracking keeps the word legible at 10px.
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
