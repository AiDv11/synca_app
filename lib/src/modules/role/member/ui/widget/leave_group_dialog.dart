import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';

/// Asks before a member leaves their group.
///
/// Returns true only if they confirmed. Null — which is what a tap outside or
/// the back button gives — means no, and every caller must treat it that way
/// rather than testing for "not false".
///
/// Deliberately shaped like `showReleaseTaskDialog`: same rounded white card,
/// navy title, the affected thing quoted back first, then the consequences in
/// charcoal, then a quiet Cancel beside a red confirm. Two destructive
/// confirmations that looked different would make the pattern harder to trust
/// than either of them alone.
///
/// [groupId] is the group's code, shown for the same reason the release dialog
/// quotes the task title: it is the last cheap moment to notice this is the
/// wrong group.
Future<bool?> showLeaveGroupDialog({
  required BuildContext context,
  required String groupId,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Leave this group?',
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
            groupId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              // The code is typed in and compared by eye, so a little tracking
              // makes a transposed character easier to catch here.
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "You will lose access to the group's board — its tasks, the claim "
            'list and your timeline all disappear while you are out. This is '
            'enforced by the database, not just hidden in the app.\n\n'
            'Nothing is deleted. Tasks you claimed stay yours, and joining '
            'again with the same code brings the whole board back.',
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
            'Leave group',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
