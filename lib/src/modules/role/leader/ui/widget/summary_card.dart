import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';

/// One of the three top cards on the Team Dashboard.
///
/// Big number on top, short label underneath. The wireframe shows
/// `68% / progress`, `3 / at risk`, `5 / members` — same shape, three times.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.value,
    required this.label,
    this.emphasise = false,
  });

  /// The big figure — already formatted (`'68%'`, `'3'`, `'5'`).
  final String value;

  /// Lowercase label under the figure (`'progress'`, `'at risk'`, `'members'`).
  final String label;

  /// When true, the number uses [AppColors.danger] — for the at-risk count
  /// when it is above zero, so the card itself signals trouble.
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: emphasise
              ? Border.all(color: AppColors.danger.withValues(alpha: 0.35))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                color: emphasise ? AppColors.danger : AppColors.navy,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.charcoal,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
