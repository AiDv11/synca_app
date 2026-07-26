import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/common/auth/model/services/auth_service.dart';
import 'package:synca_app/src/modules/role/member/ui/page/my_tasks_page.dart';

/// Home shell for a Group Member.
///
/// This widget owns the bottom navigation and nothing else — each tab's content
/// is its own widget. Keeping the shell dumb means the Tasks tab can grow
/// without this file growing with it, and the Group and Timeline tabs can be
/// filled in later by editing one line each.
///
/// It takes the signed-in [AppUser] because everything below needs it: the uid
/// to stream that member's tasks, the name to stamp on a claim, the group id to
/// list unclaimed work. `AuthGate` has already loaded it, so passing it down
/// avoids every screen re-fetching the same profile.
class MemberDashboard extends StatefulWidget {
  const MemberDashboard({super.key, required this.user});

  final AppUser user;

  @override
  State<MemberDashboard> createState() => _MemberDashboardState();
}

class _MemberDashboardState extends State<MemberDashboard> {
  /// Which tab is showing. The one piece of state this shell has.
  int _selectedIndex = 0;

  static const List<String> _titles = [
    'My Tasks',
    'My Group',
    'Timeline',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        // Flutter 3 tints the app bar when content scrolls under it, which
        // muddies the navy. Zero keeps it flat and on-brand.
        scrolledUnderElevation: 0,
      ),

      // IndexedStack builds all four tabs and shows one, keeping the other
      // three alive off-screen. That's the point: switch to Profile and back
      // and the Tasks tab still has its scroll position and its open Firestore
      // stream. Swapping in a single child instead would rebuild the tab from
      // scratch every time, re-running the query and jumping to the top.
      //
      // The trade-off is that all four are built at once, so this is right for
      // a handful of tabs and wrong for dozens.
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            MyTasksPage(user: widget.user),
            const _ComingSoon(
              icon: Icons.groups_outlined,
              title: 'My Group',
              message:
                  'Your group members and their workload will appear here.',
            ),
            const _ComingSoon(
              icon: Icons.timeline_outlined,
              title: 'Timeline',
              message: 'Your contribution history will appear here.',
            ),
            _ProfileTab(user: widget.user),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        // setState is what makes the tap visible: it updates the field and
        // tells Flutter to rebuild, which moves both the IndexedStack and the
        // highlighted icon.
        onTap: (index) => setState(() => _selectedIndex = index),
        // With four or more items the default behaviour hides the unselected
        // labels and shifts the icons around. `fixed` keeps all four labels on
        // screen and stops the row from dancing when you tap.
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.teal,
        unselectedItemColor: AppColors.charcoal,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.checklist_outlined),
            // The filled variant marks the active tab, so the icon reinforces
            // the colour change instead of relying on it alone.
            activeIcon: Icon(Icons.checklist),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: 'Group',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline_outlined),
            activeIcon: Icon(Icons.timeline),
            label: 'Timeline',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// The member's details and the way out of the app.
class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    // A name could in theory be empty, and `''[0]` throws a range error rather
    // than returning nothing — a crash on a screen that just shows a letter.
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.navy,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
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
          // No Navigator call. Signing out makes Firebase push a new value down
          // the auth stream; AuthGate hears it and swaps this whole screen for
          // the login page by itself.
          onPressed: AuthService().logout,
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade200),
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

/// One white row of "label / value" on the profile tab.
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

/// Placeholder for the two tabs that aren't built yet.
class _ComingSoon extends StatelessWidget {
  const _ComingSoon({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.skyBlue),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.charcoal),
            ),
          ],
        ),
      ),
    );
  }
}
