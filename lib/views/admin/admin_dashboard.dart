import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/app_user.dart';
import '../../models/chat_room.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import 'manage_clients_screen.dart';
import 'manage_caregivers_screen.dart';
import 'assignments_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_chat_list_screen.dart';
import 'admin_schedules_screen.dart';
import 'admin_clock_logs_screen.dart';
import 'weekly_hours_screen.dart';
import 'applications_screen.dart';
import '../common/chat_screen.dart';
import '../common/profile_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  final DashboardViewModel _dashVm = DashboardViewModel()..loadData();

  @override
  void dispose() {
    _dashVm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ChangeNotifierProvider.value(
        value: _dashVm,
        child: const _AdminHome(),
      ),
      const ManageClientsScreen(),
      const ManageCaregiverScreen(),
      const AdminChatListScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          // Tabs stay mounted, so re-fetch counts after edits on other tabs.
          if (i == 0 && _currentIndex != 0) {
            _dashVm.loadData(forceRefresh: true);
          }
          setState(() => _currentIndex = i);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Clients'),
          NavigationDestination(
              icon: Icon(Icons.medical_services), label: 'Caregivers'),
          NavigationDestination(icon: Icon(Icons.chat), label: 'Messages'),
        ],
      ),
    );
  }
}

class _AdminHome extends StatelessWidget {
  const _AdminHome();

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final dashVm = context.watch<DashboardViewModel>();
    final userName = authVm.currentUser?.fullName ?? 'Admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                final user = context.read<AuthViewModel>().currentUser;
                if (user == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProfileScreen(user: user)),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white24,
                  backgroundImage: (authVm.currentUser?.photoUrl ?? '')
                          .isNotEmpty
                      ? NetworkImage(authVm.currentUser!.photoUrl)
                      : null,
                  child: (authVm.currentUser?.photoUrl ?? '').isEmpty
                      ? Text(
                          ((authVm.currentUser?.fullName ?? '').isNotEmpty
                                  ? authVm.currentUser!.fullName[0]
                                  : '?')
                              .toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => dashVm.loadData(forceRefresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome
              const Text(
                'Welcome back,',
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
              ),
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // Stats cards
              Row(
                children: [
                  _buildStatCard(
                    'Total Clients',
                    '${dashVm.clientCount}',
                    Icons.people,
                    const Color(0xFF1565C0),
                    onTap: () => _openUsers(context, 'client', 'all'),
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    'Total Caregivers',
                    '${dashVm.caregiverCount}',
                    Icons.medical_services,
                    const Color(0xFF2E7D32),
                    onTap: () => _openUsers(context, 'caregiver', 'all'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatCard(
                    'Active Clients',
                    '${dashVm.activeClientCount}',
                    Icons.check_circle,
                    const Color(0xFFF57F17),
                    onTap: () => _openUsers(context, 'client', 'active'),
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    'Active Caregivers',
                    '${dashVm.activeCaregiverCount}',
                    Icons.verified,
                    const Color(0xFF6A1B9A),
                    onTap: () => _openUsers(context, 'caregiver', 'active'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatCard(
                    'Inactive Clients',
                    '${dashVm.inactiveClientCount}',
                    Icons.person_off,
                    const Color(0xFF616161),
                    onTap: () => _openUsers(context, 'client', 'inactive'),
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    'Inactive Caregivers',
                    '${dashVm.inactiveCaregiverCount}',
                    Icons.block,
                    const Color(0xFFC62828),
                    onTap: () => _openUsers(context, 'caregiver', 'inactive'),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              if (authVm.currentUser != null) ...[
                _GroupsSection(currentUser: authVm.currentUser!),
                const SizedBox(height: 28),
              ],

              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildActionTile(
                context,
                'Manage Assignments',
                'Assign caregivers to clients',
                Icons.assignment_ind,
                AppTheme.primaryColor,
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AssignmentsScreen())),
              ),
              _buildActionTile(
                context,
                'View Schedules',
                'Manage all caregiver schedules',
                Icons.calendar_month,
                AppTheme.warningColor,
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminSchedulesScreen())),
              ),
              _buildActionTile(
                context,
                'Shift Reports',
                'View all caregiver reports',
                Icons.summarize,
                const Color(0xFF6A1B9A),
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminReportsScreen())),
              ),
              _buildActionTile(
                context,
                'Weekly Hours',
                'Track caregiver hours per client',
                Icons.schedule,
                const Color(0xFF00838F),
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const WeeklyHoursScreen())),
              ),
              _buildActionTile(
                context,
                'Caregiver Applications',
                'Send links, review documents, onboard',
                Icons.how_to_reg,
                const Color(0xFF2E7D32),
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ApplicationsScreen())),
              ),
              _buildActionTile(
                context,
                'Clock-In Logs',
                'View caregiver attendance & hours',
                Icons.access_time_filled,
                const Color(0xFFE65100),
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminClockLogsScreen())),
              ),

              const SizedBox(height: 28),

              // Recent Users
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent Users',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (dashVm.recentUsers.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${dashVm.recentUsers.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              if (dashVm.isLoading && dashVm.recentUsers.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (dashVm.recentUsers.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 48,
                        color: AppTheme.textSecondary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No users yet',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < dashVm.recentUsers.length; i++) ...[
                        _buildRecentUserItem(dashVm.recentUsers[i]),
                        if (i < dashVm.recentUsers.length - 1)
                          Divider(
                            height: 1,
                            indent: 72,
                            endIndent: 16,
                            color: Colors.grey.withValues(alpha: 0.12),
                          ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentUserItem(AppUser user) {
    final roleColor = user.role == 'caregiver'
        ? AppTheme.successColor
        : user.role == 'admin'
            ? AppTheme.warningColor
            : AppTheme.primaryColor;

    final timeAgo = _formatTimeAgo(user.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: roleColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: roleColor.withValues(alpha: 0.08),
              backgroundImage:
                  user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
              child: user.photoUrl.isEmpty
                  ? Text(
                      user.fullName.isNotEmpty
                          ? user.fullName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: roleColor,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        user.role[0].toUpperCase() + user.role.substring(1),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: roleColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (user.isActive ? AppTheme.successColor : AppTheme.errorColor)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  user.isActive ? Icons.circle : Icons.circle_outlined,
                  size: 8,
                  color: user.isActive
                      ? AppTheme.successColor
                      : AppTheme.errorColor,
                ),
                const SizedBox(width: 4),
                Text(
                  user.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: user.isActive
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }

  /// Opens the client or caregiver list with a filter applied, then
  /// refreshes the counts in case something changed there.
  void _openUsers(BuildContext context, String role, String filter) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => role == 'client'
            ? ManageClientsScreen(initialFilter: filter, standalone: true)
            : ManageCaregiverScreen(initialFilter: filter, standalone: true),
      ),
    );
    if (context.mounted) {
      context.read<DashboardViewModel>().loadData(forceRefresh: true);
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, String title, String subtitle,
      IconData icon, Color color, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle,
            style: const TextStyle(color: AppTheme.textSecondary)),
        trailing:
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: onTap,
      ),
    );
  }
}

class _GroupsSection extends StatefulWidget {
  final AppUser currentUser;

  const _GroupsSection({required this.currentUser});

  @override
  State<_GroupsSection> createState() => _GroupsSectionState();
}

class _GroupsSectionState extends State<_GroupsSection> {
  late final Stream<List<ChatRoom>> _groupsStream =
      ChatService().getGroupChatsStream();
  // Collapsed by default so a long list of groups doesn't take over the
  // dashboard; the header shows the count and opens the list.
  bool _expanded = false;

  void _openGroup(ChatRoom group) {
    final isMember = group.participants.contains(widget.currentUser.uid);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUser: widget.currentUser,
          groupChatRoom: isMember ? group : null,
          readOnlyChatRoom: isMember ? null : group,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatRoom>>(
      stream: _groupsStream,
      builder: (context, snapshot) {
        final groups = snapshot.data ?? const <ChatRoom>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Group Chats',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (groups.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${groups.length}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (!snapshot.hasData)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (groups.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.group_outlined,
                        size: 40, color: AppTheme.textSecondary),
                    SizedBox(height: 8),
                    Text(
                      'No groups yet',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ListTile(
                      onTap: () => setState(() => _expanded = !_expanded),
                      leading: CircleAvatar(
                        backgroundColor:
                            AppTheme.successColor.withValues(alpha: 0.1),
                        child: const Icon(Icons.forum,
                            color: AppTheme.successColor),
                      ),
                      title: Text(
                        _expanded ? 'Hide group chats' : 'View all group chats',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${groups.length} group${groups.length == 1 ? '' : 's'}'
                        ' · latest: ${groups.first.groupName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (_expanded)
                      Divider(
                        height: 1,
                        color: Colors.grey.withValues(alpha: 0.12),
                      ),
                    if (_expanded)
                    for (int i = 0; i < groups.length; i++) ...[
                      ListTile(
                        onTap: () => _openGroup(groups[i]),
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.successColor.withValues(alpha: 0.1),
                          child: const Icon(Icons.group,
                              color: AppTheme.successColor),
                        ),
                        title: Text(
                          groups[i].groupName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${groups[i].participants.length} members'
                          '${groups[i].messagingDisabled ? ' · Messaging off' : ''}'
                          '${groups[i].lastMessage.isNotEmpty ? ' · ${groups[i].lastMessage}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppTheme.textSecondary),
                      ),
                      if (i < groups.length - 1)
                        Divider(
                          height: 1,
                          indent: 72,
                          endIndent: 16,
                          color: Colors.grey.withValues(alpha: 0.12),
                        ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
