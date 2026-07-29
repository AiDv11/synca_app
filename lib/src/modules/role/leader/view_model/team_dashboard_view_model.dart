import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/leader/model/services/group_members_service.dart';
import 'package:synca_app/src/modules/role/leader/view_model/at_risk.dart';
import 'package:synca_app/src/modules/role/leader/view_model/load_error_message.dart';

/// State for the Group Leader's Team Dashboard (Figure 3).
///
/// Subscribes to two live streams:
///
/// - every task in the leader's group → progress %, at-risk count, the list
/// - every member in the group → the members summary card
///
/// Extends [ChangeNotifier]. The page wraps itself in a `ListenableBuilder`
/// listening to this object; every [notifyListeners] call rebuilds the UI.
/// No Provider / Riverpod — matches the rest of Synca.
class TeamDashboardViewModel extends ChangeNotifier {
  TeamDashboardViewModel({
    required this.user,
    TaskService? taskService,
    GroupMembersService? membersService,
  }) : _taskService = taskService ?? TaskService(),
       _membersService = membersService ?? GroupMembersService() {
    _subscribe();
  }

  final AppUser user;
  final TaskService _taskService;
  final GroupMembersService _membersService;

  StreamSubscription<List<Task>>? _tasksSubscription;
  StreamSubscription<List<AppUser>>? _membersSubscription;

  List<Task> _tasks = const [];
  List<AppUser> _members = const [];
  bool _tasksLoading = true;
  bool _membersLoading = true;
  String? _errorMessage;

  List<Task> get tasks => List.unmodifiable(_tasks);
  List<AppUser> get members => List.unmodifiable(_members);

  /// True until both streams have delivered their first value (or failed).
  bool get isLoading => _tasksLoading || _membersLoading;

  String? get errorMessage => _errorMessage;

  bool get isEmpty =>
      !isLoading && _errorMessage == null && _tasks.isEmpty;

  int get totalTaskCount => _tasks.length;

  int get completedTaskCount =>
      _tasks.where((task) => task.status.isDone).length;

  /// Overall progress as 0–100 for the summary card's big number.
  ///
  /// Integer percent rather than 0.0–1.0 because the wireframe shows `68%`,
  /// not a progress bar. Zero tasks → 0%, never a divide-by-zero.
  int get progressPercent {
    if (totalTaskCount == 0) return 0;
    return ((completedTaskCount / totalTaskCount) * 100).round();
  }

  int get atRiskCount =>
      _tasks.where((task) => AtRisk.isAtRisk(task)).length;

  int get memberCount => _members.length;

  void _subscribe() {
    if (!user.hasGroup) {
      _tasks = const [];
      _members = const [];
      _tasksLoading = false;
      _membersLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _tasksSubscription = _taskService
        .streamTasksForGroup(user.groupId)
        .listen(
          (tasks) {
            _tasks = tasks;
            _tasksLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) {
            _tasksLoading = false;
            _errorMessage = describeLoadError(error, subject: 'tasks');
            debugPrint('streamTasksForGroup failed: $error');
            debugPrintStack(stackTrace: stackTrace);
            notifyListeners();
          },
        );

    _membersSubscription = _membersService
        .streamMembersForGroup(user.groupId)
        .listen(
          (members) {
            _members = members;
            _membersLoading = false;
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) {
            _membersLoading = false;
            // Members failing must not blank the whole dashboard: the task list
            // and progress card can still render. Store the error only if tasks
            // have nothing useful to show either; otherwise leave memberCount
            // at whatever we last had (usually 0) and log.
            debugPrint('streamMembersForGroup failed: $error');
            debugPrintStack(stackTrace: stackTrace);
            if (_tasks.isEmpty && _errorMessage == null) {
              _errorMessage = describeLoadError(error, subject: 'members');
            }
            notifyListeners();
          },
        );
  }

  /// Drops both streams and starts fresh — wired to the Retry button.
  void retry() {
    _tasksSubscription?.cancel();
    _membersSubscription?.cancel();
    _tasksLoading = true;
    _membersLoading = true;
    _errorMessage = null;
    notifyListeners();
    _subscribe();
  }

  @override
  void dispose() {
    _tasksSubscription?.cancel();
    _membersSubscription?.cancel();
    super.dispose();
  }
}
