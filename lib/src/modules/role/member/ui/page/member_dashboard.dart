import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/common/auth/model/services/auth_service.dart';

/// Home screen for a Group Member.
///
/// Placeholder for now. This is where claiming tasks, uploading proof of work
/// and the personal contribution timeline will live.
class MemberDashboard extends StatelessWidget {
  const MemberDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      appBar: AppBar(
        title: const Text('Group Member'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            // No Navigator call needed. Signing out makes Firebase push a new
            // value down the auth stream; AuthGate hears it and swaps this
            // screen for the login page by itself.
            onPressed: AuthService().logout,
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Your tasks will appear here',
          style: TextStyle(fontSize: 16, color: AppColors.charcoal),
        ),
      ),
    );
  }
}
