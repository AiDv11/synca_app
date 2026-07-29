import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/common/auth/model/services/auth_service.dart';
import 'package:synca_app/src/modules/role/leader/ui/page/leader_tasks_page.dart';
import 'package:synca_app/src/modules/role/leader/ui/page/members_page.dart';
import 'package:synca_app/src/modules/role/leader/ui/page/team_dashboard_page.dart';

/// Home shell for a Group Leader.
///
/// Owns the bottom navigation (Dashboard / Tasks / Members / Profile) and
/// nothing else — each tab is its own page. Mirrors [MemberDashboard]'s shape
/// so the three role shells stay recognisable to anyone reading the code.
///
/// ## Why this loads the user itself
///
/// `AuthGate` currently builds `const LeaderDashboard()` with no profile
/// handed down (unlike the member path, which passes `AppUser`). Changing the
/// gate would mean editing `modules/common/`, which Ali asked us not to touch.
/// So this shell fetches the signed-in profile once via [AuthService] and then
/// builds the tabs. One extra Firestore read on leader login; no shared-code
/// edit.
class LeaderDashboard extends StatefulWidget {
  const LeaderDashboard({super.key});

  @override
  State<LeaderDashboard> createState() => _LeaderDashboardState();
}

class _LeaderDashboardState extends State<LeaderDashboard> {
  final _authService = AuthService();

  late Future<AppUser?> _profileFuture;
  int _selectedIndex = 0;

  static const List<String> _titles = [
    'Team Dashboard',
    'Tasks',
    'Members',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _profileFuture = _authService.getCurrentUser();
  }

  void _retry() {
    setState(() {
      _profileFuture = _authService.getCurrentUser();
    });
  }

  void _showTab(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.light,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            backgroundColor: AppColors.light,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: AppColors.skyBlue,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "We couldn't load your leader profile.\n"
                      'Check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _retry,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: _authService.logout,
                      child: const Text('Log out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final user = snapshot.data!;

        return Scaffold(
          backgroundColor: AppColors.light,
          appBar: AppBar(
            title: Text(_titles[_selectedIndex]),
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            scrolledUnderElevation: 0,
          ),
          body: SafeArea(
            // IndexedStack keeps all four tabs alive so switching away and
            // back does not tear down Firestore streams or lose scroll.
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                TeamDashboardPage(user: user),
                LeaderTasksPage(user: user),
                MembersPage(user: user),
                _LeaderProfileTab(user: user),
              ],
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _showTab,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: AppColors.teal,
            unselectedItemColor: AppColors.charcoal,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.checklist_outlined),
                activeIcon: Icon(Icons.checklist),
                label: 'Tasks',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.groups_outlined),
                activeIcon: Icon(Icons.groups),
                label: 'Members',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Profile tab for the leader — name, role, group, log out.
class _LeaderProfileTab extends StatelessWidget {
  const _LeaderProfileTab({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            user.name,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            user.role.label,
            style: const TextStyle(fontSize: 13, color: AppColors.charcoal),
          ),
        ),
        const SizedBox(height: 24),
        _InfoTile(
          icon: Icons.email_outlined,
          label: 'Email',
          value: user.email,
        ),
        const SizedBox(height: 10),
        _InfoTile(
          icon: Icons.groups_outlined,
          label: 'Group',
          value: user.hasGroup ? user.groupId : 'Not in a group yet',
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: AuthService().logout,
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.navy),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
