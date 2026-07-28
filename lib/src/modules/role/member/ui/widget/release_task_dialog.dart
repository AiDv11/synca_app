import 'package:flutter/material.dart';

import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/core/theme/app_colors.dart';

/// Asks before handing a task back to the group.
///
/// Returns true only if the member confirmed. Null — which is what a tap
/// outside or the back button gives — means no, and every caller must treat it
/// that way rather than testing for "not false".
///
/// A dialog rather than a SnackBar with an Undo, because releasing is not
/// reversible from the member's side: the moment the owner is cleared, anybody
/// in the group can take the task, and re-claiming it is no longer their
/// decision to make. An action you cannot take back is worth one tap.
///
/// The task's title is quoted back so a mis-tap on the wrong row is caught
/// here, at the last moment where it costs nothing.
Future<bool?> showReleaseTaskDialog({
  required BuildContext context,
  required Task task,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Release this task?',
        style: TextStyle(
          color: AppColors.navy,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${task.title}"',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'It goes back to the group list and anyone can claim it — '
            'including someone else, before you change your mind.\n\n'
            'Its status resets to Not started. Any proof link you added stays '
            'on the task.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.charcoal,
              height: 1.4,
            ),
          ),
        ],
      ),
      actions: [
        // Cancel first and styled quietly. The destructive option should never
        // be the one under the thumb by default.
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: AppColors.charcoal),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Release',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
