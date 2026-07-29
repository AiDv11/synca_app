import 'package:flutter/material.dart';

import 'package:synca_app/src/core/constants/task_status.dart';
import 'package:synca_app/src/core/theme/app_colors.dart';

/// Small coloured pill showing a [TaskStatus].
///
/// Leader-module copy of the member chip so this folder does not import
/// `modules/role/member`. Keep the colours in step with that chip if either
/// changes — they are the shared status vocabulary on screen.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.compact = false});

  final TaskStatus status;
  final bool compact;

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
