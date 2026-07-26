import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/common/auth/model/services/auth_service.dart';

/// Home screen for a Group Leader.
///
/// Placeholder for now. This is where task assignment, the group progress
/// dashboard and at-risk flags will live.
class LeaderDashboard extends StatelessWidget {
  const LeaderDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      appBar: AppBar(
        title: const Text('Group Leader'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: AuthService().logout,
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Your group overview will appear here',
          style: TextStyle(fontSize: 16, color: AppColors.charcoal),
        ),
      ),
    );
  }
}
