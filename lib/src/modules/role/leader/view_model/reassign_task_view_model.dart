import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/leader/model/services/group_members_service.dart';
import 'package:synca_app/src/modules/role/leader/view_model/load_error_message.dart';

/// State for the "Reassign Task" sheet.
///
/// Two-step picker: choose a task, then choose who should own it. The sheet
/// can also clear ownership (send the task back to the pool) by picking the
/// synthetic "Unassigned" option.
///
/// Tasks and members both stream live so a task claimed or completed while the
/// sheet is open updates the lists under the leader's finger.
class ReassignTaskViewModel extends ChangeNotifier {
  ReassignTaskViewModel({
    required this.user,
    TaskService? taskService,
    GroupMembersService? membersService,
    Task? initialTask,
  }) : _taskService = taskService ?? TaskService(),
       _membersService = membersService ?? GroupMembersService(),
       _selectedTask = initialTask {
    _subscribe();
  }

  final AppUser user;
  final TaskService _taskService;
  final GroupMembersService _membersService;

  StreamSubscription<List<Task>>? _tasksSubscription;
  StreamSubscription<List<AppUser>>? _membersSubscription;

  List<Task> _tasks = const [];
  List<AppUser> _members = const [];
  Task? _selectedTask;
  AppUser? _selectedMember;

  /// When true, the next submit clears ownership instead of assigning a person.
  bool _unassign = false;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _submitError;

  List<Task> get tasks => List.unmodifiable(_tasks);
  List<AppUser> get members => List.unmodifiable(_members);
  Task? get selectedTask => _selectedTask;
  AppUser? get selectedMember => _selectedMember;
  bool get unassign => _unassign;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get submitError => _submitError;

  /// Ready to write when a task is chosen and either a member or Unassigned.
  bool get canSubmit =>
      _selectedTask != null && (_unassign || _selectedMember != null);

  void _subscribe() {
    if (!user.hasGroup) {
      _isLoading = false;
      _errorMessage = 'Join a group before reassigning tasks.';
      notifyListeners();
      return;
    }

    _tasksSubscription = _taskService
        .streamTasksForGroup(user.groupId)
        .listen(
          (tasks) {
            _tasks = tasks;
            // If the previously selected task vanished (deleted — though rules
            // forbid delete — or filtered somehow), clear the selection.
            if (_selectedTask != null &&
                !tasks.any((t) => t.id == _selectedTask!.id)) {
              _selectedTask = null;
            } else if (_selectedTask != null) {
              // Refresh the selected object with the live version so the chip
              // shows the current owner while the sheet is open.
              _selectedTask = tasks.firstWhere(
                (t) => t.id == _selectedTask!.id,
              );
            }
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) {
            _isLoading = false;
            _errorMessage = describeLoadError(error, subject: 'tasks');
            debugPrint('reassign streamTasksForGroup failed: $error');
            debugPrintStack(stackTrace: stackTrace);
            notifyListeners();
          },
        );

    _membersSubscription = _membersService
        .streamMembersForGroup(user.groupId)
        .listen(
          (members) {
            _members = members;
            if (_selectedMember != null &&
                !members.any((m) => m.uid == _selectedMember!.uid)) {
              _selectedMember = null;
            }
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('reassign streamMembersForGroup failed: $error');
            debugPrintStack(stackTrace: stackTrace);
            // Members failing still lets the leader unassign; assigning needs
            // the list, so surface that only when they try to pick someone.
            _errorMessage ??= describeLoadError(error, subject: 'members');
            notifyListeners();
          },
        );
  }

  void selectTask(Task? task) {
    _selectedTask = task;
    _submitError = null;
    notifyListeners();
  }

  void selectMember(AppUser? member) {
    _selectedMember = member;
    _unassign = false;
    _submitError = null;
    notifyListeners();
  }

  void selectUnassigned() {
    _selectedMember = null;
    _unassign = true;
    _submitError = null;
    notifyListeners();
  }

  /// Writes the reassignment. Returns a short success sentence, or null.
  Future<String?> submit() async {
    final task = _selectedTask;
    if (task == null) {
      _submitError = 'Pick a task to reassign.';
      notifyListeners();
      return null;
    }

    if (!_unassign && _selectedMember == null) {
      _submitError = 'Pick a member, or leave the task unassigned.';
      notifyListeners();
      return null;
    }

    _isSaving = true;
    _submitError = null;
    notifyListeners();

    final ownerUid = _unassign
        ? Task.unassigned
        : _selectedMember!.uid;
    final ownerName = _unassign ? '' : _selectedMember!.name;

    try {
      await _taskService.reassignTask(
        taskId: task.id,
        ownerUid: ownerUid,
        ownerName: ownerName,
      );

      if (_unassign) {
        return 'Released "${task.title}" back to the pool';
      }
      return 'Assigned "${task.title}" to $ownerName';
    } on FirebaseException catch (e) {
      debugPrint('reassignTask failed: [${e.code}] ${e.message}');
      _submitError = e.code == 'permission-denied'
          ? "You don't have permission to reassign that task."
          : "Couldn't reassign the task. Please try again.";
      return null;
    } catch (error) {
      debugPrint('reassignTask failed: $error');
      _submitError = "Couldn't reassign the task. Please try again.";
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _tasksSubscription?.cancel();
    _membersSubscription?.cancel();
    super.dispose();
  }
}
