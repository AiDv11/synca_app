import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';

/// Shows the raw exception from a Firestore stream, with Retry and Copy.
///
/// Deliberately different from `EmptyState`: the text is **selectable** and the
/// panel **scrolls**, because a Firestore error runs several lines and often
/// ends in a URL you need to open. A centred, clipped, unselectable paragraph
/// would hide exactly the part that matters.
///
/// TODO: remove before submission — this is developer-facing. Students should
/// see a short friendly message, not an exception. It exists while the task
/// queries are being debugged.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
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
          const Icon(Icons.bug_report_outlined, size: 44, color: Colors.red),
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
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade100),
            ),
            // SelectableText, not Text, so the message can be highlighted and
            // copied — a Firestore index error hands you a long URL, and
            // retyping one by hand is miserable.
            child: SelectableText(
              message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.charcoal,
                // Monospace keeps error codes and URLs readable.
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 16),

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
          const SizedBox(height: 8),

          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              // `context` is used after an await, so the widget might be gone.
              // StatelessWidget has no `mounted`, but its BuildContext does.
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error copied'),
                  backgroundColor: AppColors.teal,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy error'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.charcoal,
              side: BorderSide(
                color: AppColors.charcoal.withValues(alpha: 0.3),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
