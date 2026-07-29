import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';

/// Form state for the "+ Add Task" sheet.
///
/// Holds the typed fields and talks to [TaskService.createTask]. The sheet
/// never imports Firestore — it reads [titleError] / [isSaving] and calls
/// [submit].
class AddTaskViewModel extends ChangeNotifier {
  AddTaskViewModel({
    required this.user,
    TaskService? taskService,
  }) : _taskService = taskService ?? TaskService();

  final AppUser user;
  final TaskService _taskService;

  String _title = '';
  String _description = '';
  DateTime? _deadline;

  /// Optional assignee. Null means the task lands in the unclaimed pool.
  AppUser? _assignee;

  String? _titleError;
  String? _deadlineError;
  String? _submitError;
  bool _isSaving = false;

  String get title => _title;
  String get description => _description;
  DateTime? get deadline => _deadline;
  AppUser? get assignee => _assignee;

  String? get titleError => _titleError;
  String? get deadlineError => _deadlineError;
  String? get submitError => _submitError;
  bool get isSaving => _isSaving;

  void setTitle(String value) {
    _title = value;
    _titleError = null;
    _submitError = null;
    notifyListeners();
  }

  void setDescription(String value) {
    _description = value;
    _submitError = null;
    notifyListeners();
  }

  void setDeadline(DateTime? value) {
    _deadline = value;
    _deadlineError = null;
    _submitError = null;
    notifyListeners();
  }

  void setAssignee(AppUser? value) {
    _assignee = value;
    _submitError = null;
    notifyListeners();
  }

  /// Validates, writes, and returns the new task's title on success.
  ///
  /// The sheet uses the returned title for its SnackBar confirmation, then
  /// pops. A null return means validation failed or the write threw — the
  /// field / submit errors are already set for the UI to show.
  Future<String?> submit() async {
    final trimmedTitle = _title.trim();
    _titleError = trimmedTitle.isEmpty ? 'Give the task a title.' : null;
    _deadlineError = _deadline == null ? 'Pick a deadline.' : null;
    _submitError = null;
    notifyListeners();

    if (_titleError != null || _deadlineError != null) return null;

    if (!user.hasGroup) {
      _submitError = 'Join a group before creating tasks.';
      notifyListeners();
      return null;
    }

    _isSaving = true;
    notifyListeners();

    try {
      final task = await _taskService.createTask(
        groupId: user.groupId,
        title: trimmedTitle,
        description: _description.trim(),
        deadline: _deadline!,
        ownerUid: _assignee?.uid ?? Task.unassigned,
        ownerName: _assignee?.name ?? '',
      );
      return task.title;
    } on FirebaseException catch (e) {
      debugPrint('createTask failed: [${e.code}] ${e.message}');
      _submitError = e.code == 'permission-denied'
          ? "You don't have permission to create tasks."
          : "Couldn't create the task. Please try again.";
      return null;
    } catch (error) {
      debugPrint('createTask failed: $error');
      _submitError = "Couldn't create the task. Please try again.";
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
