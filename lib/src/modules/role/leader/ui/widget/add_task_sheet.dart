import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/core/utils/deadline_format.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/leader/model/services/group_members_service.dart';
import 'package:synca_app/src/modules/role/leader/view_model/add_task_view_model.dart';

/// Opens the "+ Add Task" bottom sheet.
///
/// Returns the created task's title on success, or null if the sheet was
/// dismissed without saving. The caller shows the SnackBar.
Future<String?> showAddTaskSheet({
  required BuildContext context,
  required AppUser user,
  List<AppUser> members = const [],
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.light,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _AddTaskSheet(user: user, members: members),
  );
}

class _AddTaskSheet extends StatefulWidget {
  const _AddTaskSheet({required this.user, required this.members});

  final AppUser user;
  final List<AppUser> members;

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  late final AddTaskViewModel _viewModel;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  /// Members available to assign at creation time.
  ///
  /// Seeded from the dashboard's already-loaded list so the dropdown works
  /// immediately. If that list was empty (members stream still loading), we
  /// fetch once here as a fallback.
  List<AppUser> _members = const [];
  bool _loadingMembers = false;

  @override
  void initState() {
    super.initState();
    _viewModel = AddTaskViewModel(user: widget.user);
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _members = widget.members;

    if (_members.isEmpty && widget.user.hasGroup) {
      _loadMembers();
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final list = await GroupMembersService()
          .streamMembersForGroup(widget.user.groupId)
          .first;
      if (!mounted) return;
      setState(() {
        _members = list;
        _loadingMembers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMembers = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _viewModel.deadline ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.teal,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.charcoal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    // End of the chosen day — coursework deadlines are "by that date".
    _viewModel.setDeadline(
      DateTime(picked.year, picked.month, picked.day, 23, 59),
    );
  }

  Future<void> _submit() async {
    final title = await _viewModel.submit();
    if (!mounted || title == null) return;
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
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
                  'Add Task',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _titleController,
                  onChanged: _viewModel.setTitle,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    errorText: _viewModel.titleError,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _descriptionController,
                  onChanged: _viewModel.setDescription,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Deadline picker — a tappable field rather than a free-text
                // date, so the leader cannot type an unparseable string.
                InkWell(
                  onTap: _pickDeadline,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Deadline',
                      errorText: _viewModel.deadlineError,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      _viewModel.deadline == null
                          ? 'Pick a date'
                          : DeadlineFormat.dayAndMonth(_viewModel.deadline!),
                      style: TextStyle(
                        color: _viewModel.deadline == null
                            ? AppColors.charcoal.withValues(alpha: 0.5)
                            : AppColors.charcoal,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Assign to (optional)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loadingMembers
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(color: AppColors.teal),
                        )
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            // ignore: deprecated_member_use
                            value: _viewModel.assignee?.uid,
                            hint: const Text('Leave unassigned'),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Leave unassigned'),
                              ),
                              ..._members.map(
                                (m) => DropdownMenuItem<String?>(
                                  value: m.uid,
                                  child: Text(m.name),
                                ),
                              ),
                            ],
                            onChanged: (uid) {
                              if (uid == null) {
                                _viewModel.setAssignee(null);
                                return;
                              }
                              final match = _members.where((m) => m.uid == uid);
                              _viewModel.setAssignee(
                                match.isEmpty ? null : match.first,
                              );
                            },
                          ),
                        ),
                ),

                if (_viewModel.submitError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _viewModel.submitError!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _viewModel.isSaving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
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
                          '+ Add Task',
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
}
