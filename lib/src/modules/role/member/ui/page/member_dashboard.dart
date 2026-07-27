import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/common/auth/model/services/auth_service.dart';
import 'package:synca_app/src/modules/role/member/ui/page/group_page.dart';
import 'package:synca_app/src/modules/role/member/ui/page/my_tasks_page.dart';
import 'package:synca_app/src/modules/role/member/ui/page/timeline_page.dart';

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
  /// Which tab is showing.
  int _selectedIndex = 0;

  /// The signed-in member, as every tab below sees them.
  ///
  /// Held in State rather than read straight from `widget.user`, and this is
  /// the fix for a specific bug. `AuthGate` loads the profile **once** with a
  /// `FutureBuilder` over `getCurrentUser()` — a single Firestore `.get()`,
  /// not a stream. `AuthService` streams only Firebase Auth's credentials,
  /// which don't include `groupId`.
  ///
  /// So joining a group writes the new value to Firestore, and the `AppUser`
  /// handed down from the gate carries on saying `groupId: ''` for the rest of
  /// the session. The claim sheet reads `user.hasGroup` to decide whether to
  /// query at all, so it would keep insisting the member has no group until the
  /// app was restarted.
  ///
  /// Keeping the user here lets the Group tab report a change up and every
  /// other tab rebuild with the new value immediately.
  ///
  /// The proper fix is for the profile to be a stream, so any change to
  /// `/users/{uid}` — from any device — flows down on its own. That belongs in
  /// `AuthService` and `AuthGate`, outside this module.
  late AppUser _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  /// Rebuilds the shell with the member's new group.
  ///
  /// [AppUser] is immutable and has no `copyWith`, so a fresh one is built by
  /// hand with every other field carried across. Adding `copyWith` to
  /// `AppUser` would be tidier, but that file is in the auth module.
  void _handleGroupChanged(String groupId) {
    setState(() {
      _user = AppUser(
        uid: _user.uid,
        email: _user.email,
        name: _user.name,
        role: _user.role,
        groupId: groupId,
      );
    });
  }

  static const List<String> _titles = [
    'My Tasks',
    'My Group',
    'Timeline',
    'Profile',
  ];

  /// Named rather than a bare `2` at the call site below, so the link and the
  /// nav item can't quietly disagree if the tab order ever changes.
  static const int _timelineTabIndex = 2;

  /// The one thing that changes which tab is on screen. Both the bottom nav and
  /// the "View Timeline" link go through here.
  void _showTab(int index) => setState(() => _selectedIndex = index);

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
            // Every tab is handed `_user`, not `widget.user`, so a group change
            // reaches all of them on the next rebuild.
            MyTasksPage(
              user: _user,
              // The Tasks page can't change tabs — `_selectedIndex` lives here.
              // So it gets handed this function and calls it when the member
              // taps "View Timeline". Events flow up, and the shell stays the
              // only thing that decides which tab is showing.
              onViewTimeline: () => _showTab(_timelineTabIndex),
            ),
            GroupPage(user: _user, onGroupChanged: _handleGroupChanged),
            TimelinePage(user: _user),
            _ProfileTab(user: _user),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        // _showTab calls setState, which is what makes the tap visible: it
        // updates the field and tells Flutter to rebuild, moving both the
        // IndexedStack and the highlighted icon.
        onTap: _showTab,
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
