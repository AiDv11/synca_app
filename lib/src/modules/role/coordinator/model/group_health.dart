import 'package:flutter/material.dart';
import 'package:synca_app/src/core/theme/app_colors.dart';

enum RiskLevel { onTrack, atRisk, critical }

class GroupId {
  final String id;
  final String name;
  GroupId(this.id, this.name);
}

class GroupHealth {
  final String groupId;
  final String groupName;
  final int totalTasks;
  final int completedTasks;
  final int overdueTasks;
  final DateTime? lastActivity;
  final RiskLevel riskLevel;
  final String reason;

  GroupHealth({
    required this.groupId,
    required this.groupName,
    required this.totalTasks,
    required this.completedTasks,
    required this.overdueTasks,
    this.lastActivity,
    required this.riskLevel,
    required this.reason,
  });

  double get progress => totalTasks == 0 ? 0 : completedTasks / totalTasks;

  Color get color {
    switch (riskLevel) {
      case RiskLevel.critical: return AppColors.danger;
      case RiskLevel.atRisk: return AppColors.light;
      case RiskLevel.onTrack: return AppColors.navy;
    }
  }

  String get statusLabel {
    switch (riskLevel) {
      case RiskLevel.critical: return 'Critical';
      case RiskLevel.atRisk: return 'At Risk';
      case RiskLevel.onTrack: return 'On Track';
    }
  }
}