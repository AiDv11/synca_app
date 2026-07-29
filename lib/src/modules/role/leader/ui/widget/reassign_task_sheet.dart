import 'package:flutter/material.dart';

import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/leader/ui/widget/status_chip.dart';
import 'package:synca_app/src/modules/role/leader/view_model/reassign_task_view_model.dart';

/// Opens the "Reassign Task" bottom sheet.
///
/// Returns a success sentence for a SnackBar, or null if dismissed.
Future<String?> showReassignTaskSheet({
  required BuildContext context,
  required AppUser user,
  Task? initialTask,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.light,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) =>
        _ReassignTaskSheet(user: user, initialTask: initialTask),
  );
}

class _ReassignTaskSheet extends StatefulWidget {
  const _ReassignTaskSheet({required this.user, this.initialTask});

  final AppUser user;
  final Task? initialTask;

  @override
  State<_ReassignTaskSheet> createState() => _ReassignTaskSheetState();
}

class _ReassignTaskSheetState extends State<_ReassignTaskSheet> {
  late final ReassignTaskViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ReassignTaskViewModel(
      user: widget.user,
      initialTask: widget.initialTask,
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = await _viewModel.submit();
    if (!mounted || message == null) return;
    Navigator.of(context).pop(message);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.75;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return SizedBox(
          height: height,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.charcoal.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reassign Task',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pick a task, then choose who should own it.',
                  style: TextStyle(fontSize: 13, color: AppColors.charcoal),
                ),
                const SizedBox(height: 16),

                if (_viewModel.isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.teal),
                    ),
                  )
                else if (_viewModel.errorMessage != null)
                  Expanded(
                    child: Center(
                      child: Text(
                        _viewModel.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.charcoal),
                      ),
                    ),
                  )
                else ...[
                  const Text(
                    'Task',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: _buildTaskList()),
                  const SizedBox(height: 12),
                  const Text(
                    'Assign to',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(height: 120, child: _buildMemberList()),
                ],

                if (_viewModel.submitError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _viewModel.submitError!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                FilledButton(
                  onPressed: !_viewModel.canSubmit || _viewModel.isSaving
                      ? null
                      : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.teal.withValues(
                      alpha: 0.4,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _viewModel.isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Reassign Task',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskList() {
    final tasks = _viewModel.tasks;
    if (tasks.isEmpty) {
      return const Center(
        child: Text(
          'No tasks in this group yet.',
          style: TextStyle(color: AppColors.charcoal),
        ),
      );
    }

    return ListView.separated(
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final task = tasks[index];
        final selected = _viewModel.selectedTask?.id == task.id;
        return Material(
          color: selected
              ? AppColors.teal.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _viewModel.selectTask(task),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected ? AppColors.teal : AppColors.charcoal,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          task.isClaimed
                              ? 'Owned by ${task.ownerName}'
                              : 'Unassigned',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.charcoal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(status: task.status, compact: true),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMemberList() {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        _MemberChip(
          label: 'Unassigned',
          selected: _viewModel.unassign,
          onTap: _viewModel.selectUnassigned,
        ),
        ..._viewModel.members.map(
          (member) => _MemberChip(
            label: member.name,
            selected:
                !_viewModel.unassign &&
                _viewModel.selectedMember?.uid == member.uid,
            onTap: () => _viewModel.selectMember(member),
          ),
        ),
      ],
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.teal.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: selected ? AppColors.teal : AppColors.charcoal,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(
          color: selected ? AppColors.teal : AppColors.charcoal.withValues(
            alpha: 0.2,
          ),
        ),
        backgroundColor: Colors.white,
      ),
    );
  }
}
