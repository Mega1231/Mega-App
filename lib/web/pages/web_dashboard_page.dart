import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/chat_room.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../admin_web_shell.dart';
import '../web_widgets.dart';

class WebDashboardPage extends StatefulWidget {
  const WebDashboardPage({super.key});

  @override
  State<WebDashboardPage> createState() => _WebDashboardPageState();
}

class _WebDashboardPageState extends State<WebDashboardPage> {
  final _vm = DashboardViewModel();
  late final Stream<List<ChatRoom>> _groups =
      ChatService().getGroupChatsStream();

  @override
  void initState() {
    super.initState();
    _vm.loadData(forceRefresh: true);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthViewModel>().currentUser?.fullName ?? '';
    return ChangeNotifierProvider.value(
      value: _vm,
      child: WebPageScaffold(
        onRefresh: () => _vm.loadData(forceRefresh: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WebPageHeader(
              title: 'Welcome back, ${name.split(' ').first}',
              subtitle: DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
              actions: [
                OutlinedButton.icon(
                  onPressed: () => _vm.loadData(forceRefresh: true),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const _KpiGrid(),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, c) {
                final groups = _GroupsPanel(stream: _groups);
                const recent = _RecentPanel();
                if (c.maxWidth < 1000) {
                  return Column(
                    children: [groups, const SizedBox(height: 24), recent],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: groups),
                    const SizedBox(width: 24),
                    const Expanded(flex: 2, child: recent),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();
    final loading = vm.isLoading && vm.clientCount == 0;
    String n(int v) => loading ? '–' : '$v';
    final tiles = [
      WebStatTile(
        icon: Icons.people_alt_outlined,
        color: AppTheme.primaryColor,
        value: n(vm.activeClientCount),
        label: 'Active clients',
        caption: loading
            ? null
            : '${vm.clientCount} total · ${vm.inactiveClientCount} inactive',
        onTap: () => WebNavigator.of(context, WebSection.clients, filter: 1),
      ),
      WebStatTile(
        icon: Icons.medical_services_outlined,
        color: AppTheme.successColor,
        value: n(vm.activeCaregiverCount),
        label: 'Active caregivers',
        caption: loading
            ? null
            : '${vm.caregiverCount} total · ${vm.inactiveCaregiverCount} inactive',
        onTap: () => WebNavigator.of(context, WebSection.caregivers, filter: 1),
      ),
      WebStatTile(
        icon: Icons.person_off_outlined,
        color: AppTheme.textSecondary,
        value: n(vm.inactiveClientCount),
        label: 'Inactive clients',
        onTap: () => WebNavigator.of(context, WebSection.clients, filter: 2),
      ),
      WebStatTile(
        icon: Icons.block,
        color: AppTheme.errorColor,
        value: n(vm.inactiveCaregiverCount),
        label: 'Inactive caregivers',
        onTap: () => WebNavigator.of(context, WebSection.caregivers, filter: 2),
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final perRow = c.maxWidth >= 1100 ? 4 : 2;
        const gap = 16.0;
        final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

class _PanelTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _PanelTitle(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _GroupsPanel extends StatelessWidget {
  final Stream<List<ChatRoom>> stream;
  const _GroupsPanel({required this.stream});

  @override
  Widget build(BuildContext context) {
    return WebCard(
      padding: EdgeInsets.zero,
      child: StreamBuilder<List<ChatRoom>>(
        stream: stream,
        builder: (context, snap) {
          final groups = snap.data ?? const <ChatRoom>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PanelTitle(
                'Group chats',
                trailing: Text(
                  '${groups.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const Divider(height: 1, color: WebTokens.border),
              if (snap.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: WebEmptyState(
                    icon: Icons.forum_outlined,
                    message: 'No group chats yet',
                  ),
                )
              else
                for (final g in groups.take(8)) _GroupRow(group: g),
            ],
          );
        },
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  final ChatRoom group;
  const _GroupRow({required this.group});

  @override
  Widget build(BuildContext context) {
    final time = group.lastMessageTime;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: WebTokens.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.groups_outlined,
                size: 20, color: AppTheme.successColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.groupName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  group.lastMessage.isNotEmpty
                      ? group.lastMessage
                      : '${group.participants.length} members',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          if (group.messagingDisabled) ...[
            const WebStatusBadge(
                label: 'Messaging off', color: AppTheme.errorColor),
            const SizedBox(width: 12),
          ],
          SizedBox(
            width: 70,
            child: Text(
              time == null ? '' : DateFormat('MMM d').format(time),
              textAlign: TextAlign.right,
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentPanel extends StatelessWidget {
  const _RecentPanel();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();
    return WebCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelTitle('Recently added'),
          const Divider(height: 1, color: WebTokens.border),
          if (vm.recentUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: vm.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : const WebEmptyState(
                      icon: Icons.person_add_alt, message: 'No users yet'),
            )
          else
            for (final u in vm.recentUsers)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    WebAvatar(name: u.fullName, photoUrl: u.photoUrl),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.fullName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${u.role[0].toUpperCase()}${u.role.substring(1)} · added ${DateFormat('MMM d').format(u.createdAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    WebStatusBadge.active(u.isActive),
                  ],
                ),
              ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
