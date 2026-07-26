import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';

/// The card at the top of My Tasks: "3 of 8 tasks completed", with a bar.
///
/// Takes plain numbers rather than a ViewModel or a list of tasks. That keeps
/// it dumb and reusable — it can't accidentally depend on how the member screen
/// works, and the leader module can hand it group-wide figures later.
class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.completedCount,
    required this.totalCount,
    required this.progress,
  });

  final int completedCount;
  final int totalCount;

  /// 0.0 to 1.0. Passed in rather than computed here so the ViewModel stays the
  /// single place that decides what "progress" means.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Navy fill makes this the anchor of the screen — the first thing the
        // eye lands on, and a clear break from the white task cards below.
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            // Pushes the two children to opposite ends of the row.
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My contribution',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: AppColors.teal,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            // Dart picks the plural at build time. "1 tasks completed" is the
            // kind of detail that makes an app feel unfinished.
            totalCount == 1
                ? '$completedCount of 1 task completed'
                : '$completedCount of $totalCount tasks completed',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 14),

          // ClipRRect rounds the ends of the bar. LinearProgressIndicator draws
          // square corners of its own; clipping is how you round them.
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              // `valueColor` wants an Animation, not a Color. AlwaysStoppedAnimation
              // is the adapter for "this one colour, never changing".
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.teal),
            ),
          ),
        ],
      ),
    );
  }
}
