import 'package:flutter/material.dart';
import 'package:synca_app/src/core/services/task_service.dart';
import '../model/group_health.dart';

class CoordinatorViewModel extends ChangeNotifier {
  final TaskService _taskService = TaskService();

  List<GroupHealth> _allGroups = [];
  List<GroupHealth> filteredGroups = [];
  RiskLevel? currentFilter;
  bool isLoading = true;

  // Mocked for the UI implementation
  final List<GroupId> _monitoredGroups = [
    GroupId('g1', 'Alpha Squad'),
    GroupId('g2', 'Beta Builders'),
    GroupId('g3', 'Gamma Group'),
  ];

  CoordinatorViewModel() {
    refresh();
  }

  Future<void> refresh() async {
    isLoading = true;
    notifyListeners();

    List<GroupHealth> healthList = [];
    for (var g in _monitoredGroups) {
      final tasks = await _taskService.streamTasksForGroup(g.id).first;
      healthList.add(_calculateHealth(g, tasks));
    }

    _allGroups = healthList;
    _applyFilter();
    isLoading = false;
    notifyListeners();
  }

  GroupHealth _calculateHealth(GroupId group, List<dynamic> tasks) {
    int total = tasks.length;
    int completed = tasks.where((t) => t.status.name == 'completed').length;
    int overdue = tasks.where((t) => t.deadline.isBefore(DateTime.now()) && t.status.name != 'completed').length;

    DateTime? lastUpdate;
    for(var t in tasks) {
      if(lastUpdate == null || t.lastUpdatedAt.isAfter(lastUpdate)) {
        lastUpdate = t.lastUpdatedAt;
      }
    }

    RiskLevel level = RiskLevel.onTrack;
    String reason = "All tasks on schedule";
    final daysSinceActivity = lastUpdate != null ? DateTime.now().difference(lastUpdate).inDays : 99;

    if (overdue > 0 || daysSinceActivity >= 7) {
      level = RiskLevel.critical;
      reason = overdue > 0 ? "$overdue overdue tasks" : "No activity in 7+ days";
    } else {
      double progress = total == 0 ? 0 : completed / total;
      bool tightDeadline = tasks.any((t) => t.deadline.difference(DateTime.now()).inDays <= 3 && t.status.name != 'completed');
      if (tightDeadline && progress < 0.5) {
        level = RiskLevel.atRisk;
        reason = "Tight deadlines with <50% progress";
      }
    }

    return GroupHealth(
      groupId: group.id,
      groupName: group.name,
      totalTasks: total,
      completedTasks: completed,
      overdueTasks: overdue,
      lastActivity: lastUpdate,
      riskLevel: level,
      reason: reason,
    );
  }

  void setFilter(RiskLevel? level) {
    currentFilter = level;
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    if (currentFilter == null) {
      filteredGroups = List.from(_allGroups);
    } else {
      filteredGroups = _allGroups.where((g) => g.riskLevel == currentFilter).toList();
    }
    filteredGroups.sort((a, b) => a.riskLevel.index.compareTo(b.riskLevel.index));
  }
}
