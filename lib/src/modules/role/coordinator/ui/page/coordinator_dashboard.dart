import 'package:flutter/material.dart';
import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/common/auth/model/services/auth_service.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/avatar_picker_sheet.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/change_password_sheet.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/member_avatar.dart';
import 'package:synca_app/src/modules/role/member/view_model/avatar_picker_view_model.dart';
import '../../view_model/coordinator_view_model.dart';
import '../../model/group_health.dart';

class CoordinatorDashboard extends StatefulWidget {
  final AppUser user;
  const CoordinatorDashboard({super.key, required this.user});

  @override
  State<CoordinatorDashboard> createState() => _CoordinatorDashboardState();
}

class _CoordinatorDashboardState extends State<CoordinatorDashboard> {
  final CoordinatorViewModel _viewModel = CoordinatorViewModel();
  int _selectedIndex = 0;

  static const List<String> _titles = ['Overview', 'Flagged Groups', 'Profile'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildOverviewTab(),
            _buildFlaggedTab(),
            _ProfileTab(user: widget.user),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: AppColors.teal,
        unselectedItemColor: AppColors.charcoal,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Overview'),
          BottomNavigationBarItem(icon: Icon(Icons.flag_outlined), activeIcon: Icon(Icons.flag), label: 'Flagged'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        if (_viewModel.isLoading) return const Center(child: CircularProgressIndicator());
        return Column(
          children: [
            _buildFilters(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _viewModel.filteredGroups.length,
                itemBuilder: (context, index) => _GroupHealthCard(
                  group: _viewModel.filteredGroups[index],
                  onFlagToggle: () => _viewModel.toggleFlag(_viewModel.filteredGroups[index].groupId),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFlaggedTab() {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        if (_viewModel.flaggedGroups.isEmpty) {
          return const Center(
            child: Text('No flagged groups', style: TextStyle(color: AppColors.charcoal)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _viewModel.flaggedGroups.length,
          itemBuilder: (context, index) => _GroupHealthCard(
            group: _viewModel.flaggedGroups[index],
            onFlagToggle: () => _viewModel.toggleFlag(_viewModel.flaggedGroups[index].groupId),
          ),
        );
      },
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: _viewModel.currentFilter == null,
            onSelected: (_) => _viewModel.setFilter(null),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Critical'),
            selected: _viewModel.currentFilter == RiskLevel.critical,
            onSelected: (_) => _viewModel.setFilter(RiskLevel.critical),
            selectedColor: AppColors.danger.withOpacity(0.2),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('At Risk'),
            selected: _viewModel.currentFilter == RiskLevel.atRisk,
            onSelected: (_) => _viewModel.setFilter(RiskLevel.atRisk),
            selectedColor: AppColors.navy.withOpacity(0.2),
          ),
        ],
      ),
    );
  }
}

class _GroupHealthCard extends StatelessWidget {
  final GroupHealth group;
  final VoidCallback onFlagToggle;
  const _GroupHealthCard({required this.group, required this.onFlagToggle});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(group.groupName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
            ),
            if (group.isFlagged) const Icon(Icons.flag, color: AppColors.danger, size: 18),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(group.statusLabel, style: TextStyle(color: group.color, fontWeight: FontWeight.bold, fontSize: 12)),
            Text(group.reason, style: const TextStyle(fontSize: 13, color: AppColors.charcoal)),
          ],
        ),
        trailing: IconButton(
          icon: Icon(group.isFlagged ? Icons.flag : Icons.flag_outlined),
          color: group.isFlagged ? AppColors.danger : AppColors.charcoal,
          onPressed: onFlagToggle,
        ),
        onTap: () => _showGroupDetails(context),
      ),
    );
  }

  void _showGroupDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.groupName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const Divider(height: 32),
            _row('Progress', '${(group.progress * 100).toInt()}%'),
            _row('Total Tasks', group.totalTasks.toString()),
            _row('Completed', group.completedTasks.toString()),
            _row('Overdue Tasks', group.overdueTasks.toString(), color: group.overdueTasks > 0 ? AppColors.danger : null),
            const SizedBox(height: 20),
            const Text(
              'Privacy Note: Detailed task titles and descriptions are restricted to group members.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 11, color: AppColors.charcoal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String val, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label),
      Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
    ]),
  );
}

class _ProfileTab extends StatefulWidget {
  final AppUser user;
  const _ProfileTab({required this.user});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late final AvatarPickerViewModel _avatarViewModel;

  @override
  void initState() {
    super.initState();
    _avatarViewModel = AvatarPickerViewModel(uid: widget.user.uid);
    _avatarViewModel.load();
  }

  @override
  void dispose() {
    _avatarViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        Center(
          child: ListenableBuilder(
            listenable: _avatarViewModel,
            builder: (context, _) => Stack(
              children: [
                MemberAvatar(avatarId: _avatarViewModel.avatarId, name: user.name, radius: 40),
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.teal, shape: BoxShape.circle, border: Border.all(color: AppColors.light, width: 2)),
                    child: const Icon(Icons.edit, size: 14, color: Colors.white),
                  ),
                ),
                Positioned.fill(child: Material(color: Colors.transparent, shape: const CircleBorder(), clipBehavior: Clip.antiAlias, child: InkWell(onTap: _changeAvatar))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(child: Text(user.name, style: const TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.bold))),
        Center(child: Text(user.role.label, style: const TextStyle(fontSize: 13, color: AppColors.charcoal))),
        const SizedBox(height: 24),
        _tile(Icons.email_outlined, 'Email', user.email),
        const SizedBox(height: 10),
        _actionTile(Icons.lock_outline, 'Change password', _changePassword),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: AuthService().logout,
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade200),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _tile(IconData icon, String label, String value) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      Icon(icon, size: 20, color: AppColors.navy),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.charcoal)),
        Text(value, style: const TextStyle(fontSize: 14, color: AppColors.navy, fontWeight: FontWeight.w600)),
      ]),
    ]),
  );

  Widget _actionTile(IconData icon, String label, VoidCallback onTap) => Material(
    color: Colors.white, borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.navy),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.navy, fontWeight: FontWeight.w600))),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.charcoal),
        ]),
      ),
    ),
  );

  Future<void> _changePassword() async {
    if (await showChangePasswordSheet(context) == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated'), backgroundColor: AppColors.teal));
    }
  }

  Future<void> _changeAvatar() async {
    if (await showAvatarPickerSheet(context: context, viewModel: _avatarViewModel) == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avatar updated'), backgroundColor: AppColors.teal));
    }
  }
}