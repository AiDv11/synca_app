import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/leader/model/services/group_members_service.dart';
import 'package:synca_app/src/modules/role/leader/view_model/load_error_message.dart';

/// One row on the Members tab: a person and how many tasks they currently own.
class MemberWorkload {
  const MemberWorkload({required this.member, required this.ownedCount});

  final AppUser member;
  final int ownedCount;
}

/// State for the Members tab: who is in the group, and how many tasks each
/// person currently owns.
///
/// Task ownership is derived from the live task stream rather than stored on
/// the user document, so a reassignment on the Dashboard updates the workload
/// numbers here without a second write.
class MembersViewModel extends ChangeNotifier {
  MembersViewModel({
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

  List<AppUser> get members => List.unmodifiable(_members);

  bool get isLoading => _tasksLoading || _membersLoading;

  String? get errorMessage => _errorMessage;

  bool get isEmpty =>
      !isLoading && _errorMessage == null && _members.isEmpty;

  /// How many open (not completed) tasks [member] currently owns.
  int openTaskCountFor(AppUser member) {
    return _tasks
        .where(
          (task) => task.ownerUid == member.uid && !task.status.isDone,
        )
        .length;
  }

  /// Members paired with ownership counts, ready for the list UI.
  List<MemberWorkload> get workloads => _members
      .map(
        (member) => MemberWorkload(
          member: member,
          ownedCount: openTaskCountFor(member),
        ),
      )
      .toList(growable: false);

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

    _tasksSubscription = _taskService.streamTasksForGroup(user.groupId).listen(
      (tasks) {
        _tasks = tasks;
        _tasksLoading = false;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        _tasksLoading = false;
        _errorMessage = describeLoadError(error, subject: 'tasks');
        debugPrint('MembersViewModel tasks failed: $error');
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
            _errorMessage = null;
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) {
            _membersLoading = false;
            _errorMessage = describeLoadError(error, subject: 'members');
            debugPrint('MembersViewModel members failed: $error');
            debugPrintStack(stackTrace: stackTrace);
            notifyListeners();
          },
        );
  }

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
