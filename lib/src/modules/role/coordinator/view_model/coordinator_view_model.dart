import 'package:flutter/material.dart';
import 'package:synca_app/src/core/services/task_service.dart';
import '../model/group_health.dart';

class CoordinatorViewModel extends ChangeNotifier {
  // ignore: unused_field
  final TaskService _taskService = TaskService();

  List<GroupHealth> _allGroups = [];
  List<GroupHealth> filteredGroups = [];
  List<GroupHealth> flaggedGroups = [];
  RiskLevel? currentFilter;
  bool isLoading = true;

  final List<GroupId> _monitoredGroups = [
    GroupId('g1', 'Alpha Squad'),
    GroupId('g2', 'Beta Builders'),
    GroupId('g3', 'Gamma Group'),
    GroupId('g4', 'Delta Design'),
  ];

  CoordinatorViewModel() {
    refresh();
  }

  Future<void> refresh() async {
    try {
      isLoading = true;
      notifyListeners();

      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 800));

      // Mocking different states for demonstration
      _allGroups = [
        GroupHealth(
          groupId: 'g1',
          groupName: 'Alpha Squad',
          totalTasks: 10,
          completedTasks: 2,
          overdueTasks: 3, // CRITICAL: Overdue tasks
          lastActivity: DateTime.now().subtract(const Duration(days: 1)),
          riskLevel: RiskLevel.critical,
          reason: "3 overdue tasks",
        ),
        GroupHealth(
          groupId: 'g2',
          groupName: 'Beta Builders',
          totalTasks: 8,
          completedTasks: 3,
          overdueTasks: 0, // AT RISK: Tight deadline, low progress
          lastActivity: DateTime.now().subtract(const Duration(hours: 5)),
          riskLevel: RiskLevel.atRisk,
          reason: "Tight deadlines with <50% progress",
        ),
        GroupHealth(
          groupId: 'g3',
          groupName: 'Gamma Group',
          totalTasks: 12,
          completedTasks: 10,
          overdueTasks: 0, // ON TRACK
          lastActivity: DateTime.now().subtract(const Duration(minutes: 30)),
          riskLevel: RiskLevel.onTrack,
          reason: "All tasks on schedule",
        ),
        GroupHealth(
          groupId: 'g4',
          groupName: 'Delta Design',
          totalTasks: 5,
          completedTasks: 0,
          overdueTasks: 0, // CRITICAL: Inactivity
          lastActivity: DateTime.now().subtract(const Duration(days: 10)),
          riskLevel: RiskLevel.critical,
          reason: "No activity in 7+ days",
        ),
      ];

      _applyFilter();
    } catch (e) {
      debugPrint("Error refreshing coordinator dashboard: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void toggleFlag(String groupId) {
    final group = _allGroups.firstWhere((g) => g.groupId == groupId);
    group.isFlagged = !group.isFlagged;
    _applyFilter();
    notifyListeners();
  }

  void setFilter(RiskLevel? level) {
    currentFilter = level;
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    // Standard Filter
    if (currentFilter == null) {
      filteredGroups = List.from(_allGroups);
    } else {
      filteredGroups = _allGroups.where((g) => g.riskLevel == currentFilter).toList();
    }

    // Sort: Critical (0) -> At Risk (1) -> On Track (2)
    filteredGroups.sort((a, b) => a.riskLevel.index.compareTo(b.riskLevel.index));

    // Flagged List
    flaggedGroups = _allGroups.where((g) => g.isFlagged).toList();
  }
}