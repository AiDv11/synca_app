import 'package:flutter/material.dart';

import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/role/member/model/proof_link.dart';

/// Asks before taking the proof link off a task.
///
/// Returns true only if the member confirmed. Null — which is what a tap
/// outside or the back button gives — means no, and every caller must treat it
/// that way rather than testing for "not false".
///
/// Worth a confirmation even though it is only one field: proof is the evidence
/// this app exists to keep. The link is not recoverable from inside the app
/// once it is gone, and the task can carry on looking finished without it.
///
/// Same shape as `showReleaseTaskDialog` and `showLeaveGroupDialog` — white
/// card at radius 16, navy title, the affected thing quoted back first, then
/// the consequences, then a quiet Cancel beside a red confirm.
Future<bool?> showRemoveProofDialog({
  required BuildContext context,
  required Task task,
}) {
  // The dialog is only ever reached from the edit-proof step, which is itself
  // only offered when proof exists — so this is never called on a task without
  // one. Falling back to the raw string keeps it honest if that ever changes.
  final proofUrl = task.proofUrl ?? '';

  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Remove this proof?',
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
            ProofLink.displayLabel(proofUrl),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'The link comes off the task and off your timeline. The task keeps '
            'its status, so it will still look submitted — with nothing to '
            'show for it.\n\n'
            'Nothing here remembers the address, so you will need it again to '
            'put it back.',
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
            'Remove',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
