import 'package:flutter/material.dart';

import 'package:synca_app/src/core/constants/task_status.dart';
import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/status_chip.dart';

/// Slides up the status list for [task] and waits for a choice.
///
/// Returns the chosen [TaskStatus], or null if the member backed out — either
/// by tapping the status it already has, or by swiping the sheet away. Callers
/// must handle null; a null return means "do nothing", not an error.
///
/// A top-level function rather than a widget because that's how it reads at the
/// call site: `final status = await showStatusPicker(...)`. The `await` pauses
/// until the sheet closes, so the code that follows can just use the answer,
/// with no callback needed.
///
/// The `<TaskStatus>` on `showModalBottomSheet` is what types the return value.
/// Leave it off and you get `Future<dynamic>`, and every mistake below becomes
/// a runtime crash instead of a compile error.
Future<TaskStatus?> showStatusPicker({
  required BuildContext context,
  required Task task,
}) {
  return showModalBottomSheet<TaskStatus>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _StatusPickerSheet(task: task),
  );
}

class _StatusPickerSheet extends StatelessWidget {
  const _StatusPickerSheet({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          // Without this the column tries to fill the screen and the sheet
          // opens full height. `min` makes it hug its children.
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The little grab handle every bottom sheet has — it's just a
            // rounded grey box, but its absence is noticeable.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Update status',
                style: TextStyle(fontSize: 13, color: AppColors.charcoal),
              ),
            ),
            const Divider(height: 1),

            // The spread operator `...` drops a whole list of widgets into this
            // one. TaskStatus.values is already in lifecycle order, so the rows
            // come out Not started → In progress → Ready for review → Completed
            // with no sorting.
            ...TaskStatus.values.map(
              (status) => _StatusRow(
                status: status,
                isCurrent: status == task.status,
                // Pops the sheet and hands this status back to the awaiting
                // caller — this argument is what `showStatusPicker` returns.
                onTap: () => Navigator.of(context).pop(status),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// One selectable status row.
class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.status,
    required this.isCurrent,
    required this.onTap,
  });

  final TaskStatus status;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // The current status is still tappable — choosing it just closes the
      // sheet. The ViewModel checks for "no change" and skips the write, so
      // disabling the row here would be a pointless extra rule.
      onTap: onTap,
      leading: StatusChip(status: status),
      trailing: isCurrent
          ? const Icon(Icons.check_circle, color: AppColors.teal, size: 20)
          : null,
      // Faint teal wash marks where the task is now, so the member can see the
      // current state and their options at a glance.
      tileColor: isCurrent ? AppColors.teal.withValues(alpha: 0.06) : null,
    );
  }
}
