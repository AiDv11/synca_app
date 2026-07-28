import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';

/// Shown when a screen's data could not be loaded, with a way to try again.
///
/// The message it displays comes from `describeLoadError`, which is already
/// plain English — this widget renders whatever it is handed and never
/// formats an exception itself. Raw error codes and stack traces go to
/// `debugPrint` in the ViewModel, so the developer keeps them without the
/// student ever seeing one.
///
/// Kept separate from `EmptyState` because the two mean different things.
/// Empty is a normal state with nothing to fix; this one is a failure, and the
/// Retry button is the whole point of it.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;

  /// A short, already-friendly sentence. Not an exception.
  final String message;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // Sky blue rather than red: this screen is now a polite apology with
          // a Retry button, not a fault report. Red reads as "something is
          // broken", which overstates a dropped connection and matches the
          // colour the task cards use for genuinely overdue work.
          const Icon(
            Icons.cloud_off_outlined,
            size: 44,
            color: AppColors.skyBlue,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Plain, centred, unselectable. It used to be monospace inside a
          // bordered panel, which existed so a developer could read and copy a
          // multi-line Firestore exception. A one-line apology does not need
          // any of that.
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 20),

          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Retry'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
