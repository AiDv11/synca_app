import 'package:flutter/material.dart';

import 'package:synca_app/src/core/constants/task_status.dart';
import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/role/member/model/proof_link.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/status_chip.dart';

/// What the member chose in the status picker.
///
/// A small class rather than returning a bare [TaskStatus], because the sheet
/// now answers two questions at once: which status, and what proof (if any).
/// A record would work, but a named type keeps the call site readable.
class StatusChoice {
  const StatusChoice({required this.status, this.proofUrl});

  final TaskStatus status;

  /// The proof link, already normalised by [ProofLink.normalise], or null when
  /// the member didn't supply one. Null means "leave any existing proof
  /// alone" — `TaskService.updateStatus` drops the field from the write rather
  /// than overwriting it with nothing.
  final String? proofUrl;
}

/// Slides up the status list for [task] and waits for a choice.
///
/// Returns the chosen status and proof, or null if the member backed out by
/// swiping the sheet away. Callers must handle null; it means "do nothing".
///
/// `isScrollControlled` and the `viewInsets` padding inside are what let the
/// sheet rise above the on-screen keyboard when the proof field has focus.
/// Without them the keyboard covers the very field being typed into.
Future<StatusChoice?> showStatusPicker({
  required BuildContext context,
  required Task task,
}) {
  return showModalBottomSheet<StatusChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _StatusPickerSheet(task: task),
  );
}

/// Stateful because the sheet now has two steps for some statuses.
///
/// Not started and In progress still close on tap — there is nothing more to
/// ask. Ready for review and Completed are the points where evidence matters,
/// so choosing one reveals a link field and a confirm button instead of
/// closing. That keeps the common case one tap while asking for proof exactly
/// when it is relevant.
class _StatusPickerSheet extends StatefulWidget {
  const _StatusPickerSheet({required this.task});

  final Task task;

  @override
  State<_StatusPickerSheet> createState() => _StatusPickerSheetState();
}

class _StatusPickerSheetState extends State<_StatusPickerSheet> {
  /// The status the member has picked but not yet confirmed. Null while they
  /// are still looking at the list.
  TaskStatus? _pendingStatus;

  final _proofController = TextEditingController();

  /// Set once the member submits something that isn't a URL. Held rather than
  /// recomputed on every keystroke so the message appears on submit, not while
  /// they are halfway through typing `htt`.
  String? _proofError;

  @override
  void initState() {
    super.initState();

    // Pre-fill with whatever proof the task already carries, so re-opening the
    // sheet to change a status doesn't silently blank a link they added
    // earlier. Editing it is then a deliberate act.
    final existing = widget.task.proofUrl;
    if (existing != null) _proofController.text = existing;
  }

  @override
  void dispose() {
    _proofController.dispose();
    super.dispose();
  }

  /// Which statuses ask for evidence.
  ///
  /// Both are claims *about finished work*: "someone should look at this" and
  /// "this is done". Not started and In progress claim nothing, so demanding a
  /// link there would be friction with no purpose.
  bool _needsProof(TaskStatus status) =>
      status == TaskStatus.readyForReview || status == TaskStatus.completed;

  void _selectStatus(TaskStatus status) {
    if (!_needsProof(status)) {
      // One-tap path: hand the status straight back with no proof.
      Navigator.of(context).pop(StatusChoice(status: status));
      return;
    }

    setState(() {
      _pendingStatus = status;
      _proofError = null;
    });
  }

  void _confirm() {
    final raw = _proofController.text;

    // Optional, but if they typed something it has to be usable. Saving
    // "asdf" as proof would be worse than saving nothing — it looks like
    // evidence exists right up until someone clicks it.
    if (!ProofLink.isValid(raw)) {
      setState(() {
        _proofError =
            "That doesn't look like a link. Include the full address, "
            'for example docs.google.com/document/...';
      });
      return;
    }

    Navigator.of(context).pop(
      StatusChoice(
        status: _pendingStatus!,
        // Null when the field is empty, which tells updateStatus to leave any
        // existing proof untouched rather than wipe it.
        proofUrl: ProofLink.normalise(raw),
      ),
    );
  }

  void _backToList() {
    setState(() {
      _pendingStatus = null;
      _proofError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the sheet by exactly the keyboard's height when it appears.
      // MediaQuery.viewInsets is the space the system is covering.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            // Hug the content instead of filling the screen.
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The grab handle every bottom sheet has.
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
                  widget.task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              if (_pendingStatus == null) ..._buildStatusList(),
              if (_pendingStatus != null) ..._buildProofStep(),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 — pick a status
  // ---------------------------------------------------------------------------

  List<Widget> _buildStatusList() {
    return [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Text(
          'Update status',
          style: TextStyle(fontSize: 13, color: AppColors.charcoal),
        ),
      ),
      const Divider(height: 1),

      // The spread operator drops a whole list of widgets in here.
      // TaskStatus.values is already in lifecycle order, so the rows come out
      // Not started → In progress → Ready for review → Completed unsorted.
      ...TaskStatus.values.map(
        (status) => _StatusRow(
          status: status,
          isCurrent: status == widget.task.status,
          needsProof: _needsProof(status),
          onTap: () => _selectStatus(status),
        ),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Step 2 — attach a link
  // ---------------------------------------------------------------------------

  List<Widget> _buildProofStep() {
    final status = _pendingStatus!;

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Row(
          children: [
            StatusChip(status: status),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Add a link to your work',
                style: TextStyle(fontSize: 13, color: AppColors.charcoal),
              ),
            ),
          ],
        ),
      ),
      const Divider(height: 1),

      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: TextField(
          controller: _proofController,
          autofocus: true,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _confirm(),
          // Clear the error as soon as they start fixing it, so the message
          // never contradicts what is currently in the box.
          onChanged: (_) {
            if (_proofError != null) setState(() => _proofError = null);
          },
          style: const TextStyle(color: AppColors.navy, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Link to your work',
            hintText: 'docs.google.com/document/...',
            errorText: _proofError,
            prefixIcon: const Icon(Icons.link, color: AppColors.navy),
            filled: true,
            fillColor: AppColors.light,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.teal, width: 2),
            ),
            labelStyle: const TextStyle(color: AppColors.charcoal),
          ),
        ),
      ),

      const Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Text(
          'A Google Doc, a Figma file, a GitHub commit — any link that shows '
          'what you did. Optional: you can update the status without one.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.charcoal,
            height: 1.4,
          ),
        ),
      ),

      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Row(
          children: [
            // Back rather than a second close button: the member is one tap
            // deep and may have picked the wrong status.
            TextButton(
              onPressed: _backToList,
              style: TextButton.styleFrom(foregroundColor: AppColors.charcoal),
              child: const Text('Back'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Move to ${status.label}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

/// One selectable status row.
class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.status,
    required this.isCurrent,
    required this.needsProof,
    required this.onTap,
  });

  final TaskStatus status;
  final bool isCurrent;
  final bool needsProof;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // The current status stays tappable — choosing it just closes the sheet.
      // The ViewModel skips the write when nothing changed, so disabling the
      // row here would be a rule with no purpose.
      onTap: onTap,
      leading: StatusChip(status: status),
      trailing: isCurrent
          ? const Icon(Icons.check_circle, color: AppColors.teal, size: 20)
          : needsProof
          // A quiet hint that this row asks a follow-up question rather than
          // closing the sheet, so the second step isn't a surprise.
          ? Icon(
              Icons.link,
              size: 18,
              color: AppColors.charcoal.withValues(alpha: 0.4),
            )
          : null,
      tileColor: isCurrent ? AppColors.teal.withValues(alpha: 0.06) : null,
    );
  }
}
