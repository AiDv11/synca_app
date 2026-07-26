import 'package:flutter/material.dart';

import 'package:synca_app/src/core/constants/task_status.dart';
import 'package:synca_app/src/core/theme/app_colors.dart';

/// A small coloured pill showing a task's [TaskStatus].
///
/// Its own widget rather than inline code in the task card, because the same
/// pill appears in the card, in the status picker and (later) on the leader's
/// board. One widget means one place to change the look, and no chance of the
/// three drifting apart.
///
/// `StatelessWidget` is right here: the chip draws whatever status it is handed
/// and remembers nothing. Give it a new status and Flutter rebuilds it.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.compact = false});

  final TaskStatus status;

  /// Slightly smaller, for tight rows.
  final bool compact;

  /// The brand colour for each status.
  ///
  /// The progression is deliberate: neutral charcoal for untouched work, sky
  /// blue once it is moving, navy when it needs someone's attention, and teal —
  /// the accent colour used everywhere for success — when it is done.
  ///
  /// A `switch` expression over an enum has to cover every value, so adding a
  /// fifth status later becomes a compile error here rather than a chip that
  /// silently renders in the wrong colour.
  Color get _colour => switch (status) {
    TaskStatus.notStarted => AppColors.charcoal,
    TaskStatus.inProgress => AppColors.skyBlue,
    TaskStatus.readyForReview => AppColors.navy,
    TaskStatus.completed => AppColors.teal,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        // The same colour as the text, at 12% opacity, for the background. A
        // tinted pill reads clearly without the heavy look of a solid block.
        //
        // `withValues(alpha:)` replaced the older `withOpacity()`, which is now
        // deprecated — it loses precision on wide-gamut displays.
        color: _colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: _colour,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
