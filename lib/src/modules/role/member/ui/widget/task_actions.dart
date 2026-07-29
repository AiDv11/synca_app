/// Everything a member can *do* to a task they own, in one place.
///
/// Two screens now offer the same actions — the Tasks list and the task detail
/// page — and each step is more than "call the ViewModel": open the right
/// sheet, ask for confirmation where it is destructive, decide what counts as
/// success, and say so. Written twice, the two screens would drift, and the
/// confirmation is exactly the half that gets forgotten in the copy.
///
/// Top-level functions rather than a mixin or a base class, because these need
/// nothing from the widget except its [BuildContext]. Each awaits, so each
/// checks `context.mounted` afterwards — the same rule a State follows with
/// `mounted`, and the reason none of these touch `context` blindly after a gap.
library;

import 'package:flutter/material.dart';

import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/role/member/model/proof_link.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/release_task_dialog.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/remove_proof_dialog.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/status_picker_sheet.dart';
import 'package:synca_app/src/modules/role/member/view_model/my_tasks_view_model.dart';

/// Opens the task sheet and carries out whatever the member picked.
///
/// Returns true if the task was **released**, which is the one outcome that
/// changes where the caller should be: the detail page pops, because the task
/// it was showing is no longer the member's.
///
/// [startOnProofEdit] opens the sheet directly on the link field, for the
/// detail page's "Edit proof" button.
Future<bool> openTaskSheet({
  required BuildContext context,
  required MyTasksViewModel viewModel,
  required Task task,
  bool startOnProofEdit = false,
}) async {
  final result = await showStatusPicker(
    context: context,
    task: task,
    startOnProofEdit: startOnProofEdit,
  );

  if (!context.mounted || result == null) return false;

  // Exhaustive because TaskSheetResult is sealed — there is no `default`, and a
  // fourth action added to the sheet stops this compiling until it is handled.
  switch (result) {
    case StatusChoice():
      await _applyStatusChange(context, viewModel, task, result);
      return false;
    case ProofChoice():
      await _applyProofChange(context, viewModel, task, result);
      return false;
    case ReleaseChoice():
      return confirmAndRelease(
        context: context,
        viewModel: viewModel,
        task: task,
      );
  }
}

/// Confirms, then hands the task back to the group. True if it was released.
///
/// The confirmation is here rather than inside the sheet so the sheet has
/// already closed by the time the dialog appears — a dialog stacked on a bottom
/// sheet leaves two things to dismiss and makes Cancel ambiguous.
Future<bool> confirmAndRelease({
  required BuildContext context,
  required MyTasksViewModel viewModel,
  required Task task,
}) async {
  final confirmed = await showReleaseTaskDialog(context: context, task: task);

  // `!= true` rather than `== false`, because dismissing the dialog by tapping
  // outside it returns null. Only an explicit Release goes on.
  if (!context.mounted || confirmed != true) return false;

  final error = await viewModel.releaseTask(task);
  if (!context.mounted) return false;

  if (error != null) {
    showTaskSnackBar(context, error);
    return false;
  }

  showTaskSnackBar(context, 'Released "${task.title}"', isError: false);
  return true;
}

/// Opens a task's proof link in the browser.
Future<void> openProofLink(BuildContext context, Task task) async {
  final url = task.proofUrl;

  // `hasProof`, not a null check: a task whose proof was removed holds an empty
  // string, and there is nothing to open. The `!` is safe because of it, but
  // flow analysis cannot see inside the helper.
  if (!ProofLink.hasProof(url)) return;

  final opened = await ProofLink.open(url!);
  if (!context.mounted || opened) return;

  // False means nothing on the device could handle the link — a malformed URL,
  // or no browser installed. Worth saying rather than appearing to do nothing.
  showTaskSnackBar(context, "Couldn't open that link.");
}

/// The one snackbar style both screens use.
void showTaskSnackBar(
  BuildContext context,
  String message, {
  bool isError = true,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.danger : AppColors.teal,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// ---------------------------------------------------------------------------
// Private steps
// ---------------------------------------------------------------------------

Future<void> _applyStatusChange(
  BuildContext context,
  MyTasksViewModel viewModel,
  Task task,
  StatusChoice choice,
) async {
  final error = await viewModel.changeStatus(
    task,
    choice.status,
    proofUrl: choice.proofUrl,
  );

  if (!context.mounted) return;

  if (error != null) {
    showTaskSnackBar(context, error);
    return;
  }

  // No manual list update anywhere. The write went to Firestore, Firestore
  // pushed it back down the stream, the ViewModel notified, and both the list
  // and the detail page have already redrawn by the time this runs.
  showTaskSnackBar(
    context,
    choice.proofUrl != null
        ? 'Moved to ${choice.status.label}, proof attached'
        : 'Moved to ${choice.status.label}',
    isError: false,
  );
}

/// Saves an edited proof link, or removes it after confirming.
///
/// Only the removal asks. Replacing a link is an ordinary correction, and
/// stopping to confirm it would make fixing a typo cost two taps for nothing.
Future<void> _applyProofChange(
  BuildContext context,
  MyTasksViewModel viewModel,
  Task task,
  ProofChoice choice,
) async {
  if (choice.isRemoval) {
    final confirmed = await showRemoveProofDialog(context: context, task: task);
    if (!context.mounted || confirmed != true) return;
  }

  final error = await viewModel.updateProof(task, choice.proofUrl);
  if (!context.mounted) return;

  if (error != null) {
    showTaskSnackBar(context, error);
    return;
  }

  showTaskSnackBar(
    context,
    choice.isRemoval ? 'Proof removed' : 'Proof link updated',
    isError: false,
  );
}
