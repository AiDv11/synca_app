import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/common/auth/model/services/auth_service.dart';

/// Home screen for a Module Coordinator.
///
/// Placeholder for now. This will show view-only submission health across
/// groups — progress and at-risk signals only.
///
/// Hard rule for everything built on this screen: a coordinator never sees
/// private group content. No task details, no uploaded proof, no chat. Only
/// aggregate, health-level information.
class CoordinatorDashboard extends StatelessWidget {
  const CoordinatorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      appBar: AppBar(
        title: const Text('Module Coordinator'),
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
          'Submission health will appear here',
          style: TextStyle(fontSize: 16, color: AppColors.charcoal),
        ),
      ),
    );
  }
}
