import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/change_password_dialog.dart';
import 'pages/web_assignments_page.dart';
import 'pages/web_clock_logs_page.dart';
import 'pages/web_dashboard_page.dart';
import 'pages/web_messages_page.dart';
import 'pages/web_reports_page.dart';
import 'pages/web_schedules_page.dart';
import 'pages/web_users_page.dart';
import 'pages/web_weekly_hours_page.dart';
import 'web_widgets.dart';

enum WebSection {
  dashboard('Dashboard', Icons.space_dashboard_outlined),
  clients('Clients', Icons.people_alt_outlined),
  caregivers('Caregivers', Icons.medical_services_outlined),
  assignments('Assignments', Icons.assignment_ind_outlined),
  schedules('Schedules', Icons.calendar_month_outlined),
  reports('Shift Reports', Icons.description_outlined),
  weeklyHours('Weekly Hours', Icons.schedule_outlined),
  clockLogs('Clock-In Logs', Icons.login_outlined),
  messages('Messages', Icons.forum_outlined);

  final String label;
  final IconData icon;
  const WebSection(this.label, this.icon);
}

/// Sections that open their page. The others stay in the sidebar but show
/// an "under progress" screen for the first client test round; add them
/// here to switch them on.
const enabledWebSections = {...WebSection.values};

/// Lets pages switch the visible section (e.g. a dashboard tile → Clients).
class WebNavigator extends InheritedWidget {
  final void Function(WebSection section, {int filter}) go;

  const WebNavigator({super.key, required this.go, required super.child});

  /// [filter] presets list pages: 0 all, 1 active, 2 inactive.
  static void of(BuildContext context, WebSection section, {int filter = 0}) =>
      context
          .dependOnInheritedWidgetOfExactType<WebNavigator>()!
          .go(section, filter: filter);

  @override
  bool updateShouldNotify(WebNavigator oldWidget) => false;
}

class AdminWebShell extends StatefulWidget {
  const AdminWebShell({super.key});

  @override
  State<AdminWebShell> createState() => _AdminWebShellState();
}

class _AdminWebShellState extends State<AdminWebShell> {
  WebSection _section = WebSection.dashboard;
  int _filter = 0;

  Widget _page(WebSection s) {
    if (!enabledWebSections.contains(s)) return _UnderProgressPage(section: s);
    switch (s) {
      case WebSection.dashboard:
        return const WebDashboardPage();
      case WebSection.clients:
        return WebUsersPage(role: 'client', initialFilter: _filter);
      case WebSection.caregivers:
        return WebUsersPage(role: 'caregiver', initialFilter: _filter);
      case WebSection.assignments:
        return const WebAssignmentsPage();
      case WebSection.schedules:
        return const WebSchedulesPage();
      case WebSection.reports:
        return const WebReportsPage();
      case WebSection.weeklyHours:
        return const WebWeeklyHoursPage();
      case WebSection.clockLogs:
        return const WebClockLogsPage();
      case WebSection.messages:
        return const WebMessagesPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 1100;
    return WebNavigator(
      go: (s, {int filter = 0}) => setState(() {
        _section = s;
        _filter = filter;
      }),
      child: Scaffold(
        backgroundColor: WebTokens.pageBg,
        body: Row(
          children: [
            _Sidebar(
              selected: _section,
              compact: compact,
              onSelect: (s) => setState(() {
                _section = s;
                _filter = 0;
              }),
            ),
            Expanded(
              child: Column(
                children: [
                  const _TopBar(),
                  Expanded(
                    // Keyed so each section starts fresh when revisited.
                    child: KeyedSubtree(
                      key: ValueKey('$_section-$_filter'),
                      child: _page(_section),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final WebSection selected;
  final bool compact;
  final ValueChanged<WebSection> onSelect;

  const _Sidebar({
    required this.selected,
    required this.compact,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 76 : 248,
      color: WebTokens.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 16 : 20, 22, 16, 26),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset('assets/app_icon.jpg',
                      width: 40, height: 40),
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mega Homecare',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Admin Panel',
                          style: TextStyle(
                            color: WebTokens.sidebarText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final s in WebSection.values)
                  _NavItem(
                    section: s,
                    selected: s == selected,
                    compact: compact,
                    onTap: () => onSelect(s),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final WebSection section;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _NavItem({
    required this.section,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : WebTokens.sidebarText;
    final item = Material(
      color: selected ? WebTokens.sidebarActive : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: Colors.white.withValues(alpha: 0.06),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 0 : 14, vertical: 11),
          child: Row(
            mainAxisAlignment:
                compact ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(section.icon, size: 20, color: color),
              if (!compact) ...[
                const SizedBox(width: 12),
                Text(
                  section.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: compact ? Tooltip(message: section.label, child: item) : item,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser;
    final name = user?.fullName ?? '';
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: WebTokens.border)),
      ),
      child: Row(
        children: [
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'Account',
            offset: const Offset(0, 48),
            onSelected: (v) async {
              if (v == 'profile') {
                showDialog(
                    context: context, builder: (_) => const _ProfileDialog());
                return;
              }
              if (v != 'logout') return;
              final ok = await webConfirm(
                context,
                title: 'Sign out?',
                message: 'You will need to sign in again to use the admin panel.',
                confirmLabel: 'Sign out',
              );
              if (ok && context.mounted) {
                await context.read<AuthViewModel>().logout();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 18),
                    SizedBox(width: 10),
                    Text('My profile'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 10),
                    Text('Sign out'),
                  ],
                ),
              ),
            ],
            child: Row(
              children: [
                WebAvatar(name: name, photoUrl: user?.photoUrl ?? '', size: 34),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Text(
                      'Administrator',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                const Icon(Icons.expand_more,
                    size: 20, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps a page body with the standard padding, width cap and scrolling.
class WebPageScaffold extends StatelessWidget {
  final Widget child;
  final Future<void> Function()? onRefresh;

  const WebPageScaffold({super.key, required this.child, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
      padding: WebTokens.pagePadding,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: WebTokens.maxContentWidth),
          child: child,
        ),
      ),
    );
    return onRefresh == null
        ? body
        : RefreshIndicator(onRefresh: onRefresh!, child: body);
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog();

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  bool _uploading = false;

  Future<void> _changePhoto() async {
    final picked =
        await FilePicker.pickFiles(type: FileType.image, withData: true);
    final bytes = picked?.files.single.bytes;
    if (bytes == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await context.read<AuthViewModel>().updateProfilePhotoBytes(bytes);
      if (mounted) webToast(context, 'Profile photo updated');
    } catch (e) {
      if (mounted) webToast(context, 'Could not update photo: $e', error: true);
    }
    if (mounted) setState(() => _uploading = false);
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
            ),
            Expanded(
              child: Text(value.isEmpty ? '—' : value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser!;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('My profile'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WebAvatar(name: user.fullName, photoUrl: user.photoUrl, size: 88),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _changePhoto,
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Change photo'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final changed = await showChangePasswordDialog(context);
                if (changed && context.mounted) webToast(context, 'Password changed');
              },
              icon: const Icon(Icons.lock_reset, size: 18),
              label: const Text('Change password'),
            ),
            const SizedBox(height: 16),
            const Divider(color: WebTokens.border),
            _row('Name', user.fullName),
            _row('Username', '@${user.username}'),
            _row('Role', 'Administrator'),
            _row('Phone', user.phone),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _UnderProgressPage extends StatelessWidget {
  final WebSection section;
  const _UnderProgressPage({required this.section});

  @override
  Widget build(BuildContext context) {
    return WebPageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebPageHeader(title: section.label),
          WebCard(
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(section.icon,
                        size: 30, color: AppTheme.warningColor),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Under progress',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${section.label} is being finished for the web panel and will be available soon.\nUntil then, please use the Mega Homecare mobile app for this.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
