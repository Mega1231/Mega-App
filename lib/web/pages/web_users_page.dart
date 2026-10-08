import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/manage_users_viewmodel.dart';
import '../admin_web_shell.dart';
import '../web_widgets.dart';
import 'web_reports_page.dart';
import 'web_user_form.dart';

/// Clients or caregivers as a searchable, filterable table.
class WebUsersPage extends StatefulWidget {
  final String role; // 'client' | 'caregiver'
  final int initialFilter; // 0 all, 1 active, 2 inactive

  const WebUsersPage({super.key, required this.role, this.initialFilter = 0});

  @override
  State<WebUsersPage> createState() => _WebUsersPageState();
}

class _WebUsersPageState extends State<WebUsersPage> {
  late final ManageUsersViewModel _vm = ManageUsersViewModel(role: widget.role);
  String _query = '';
  late int _filter = widget.initialFilter; // 0 all, 1 active, 2 inactive

  bool get _isClient => widget.role == 'client';
  String get _noun => _isClient ? 'client' : 'caregiver';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  /// The agency is small, so fetch every page up front; search and filters
  /// then work on the full list instead of the loaded page.
  Future<void> _loadAll() async {
    await _vm.loadUsers();
    while (mounted && _vm.hasMore) {
      final before = _vm.users.length;
      await _vm.loadMore();
      if (_vm.users.length == before) break;
    }
  }

  List<AppUser> get _visible {
    final q = _query.trim().toLowerCase();
    return _vm.users.where((u) {
      if (_filter == 1 && !u.isActive) return false;
      if (_filter == 2 && u.isActive) return false;
      if (q.isEmpty) return true;
      return u.fullName.toLowerCase().contains(q) ||
          u.username.toLowerCase().contains(q) ||
          u.address.toLowerCase().contains(q) ||
          u.phone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _vm,
      child: Consumer<ManageUsersViewModel>(
        builder: (context, vm, _) {
          final rows = _visible;
          return WebPageScaffold(
            onRefresh: _loadAll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WebPageHeader(
                  title: _isClient ? 'Clients' : 'Caregivers',
                  subtitle:
                      '${vm.totalCount} total · ${vm.activeCount} active · ${vm.inactiveCount} inactive',
                  actions: [
                    OutlinedButton.icon(
                      onPressed: _loadAll,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _openForm(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('Add ${_isClient ? 'client' : 'caregiver'}'),
                    ),
                  ],
                ),
                WebToolbar(

                  leading: [

                    WebFilterTabs(
                      labels: [
                        'All (${vm.totalCount})',
                        'Active (${vm.activeCount})',
                        'Inactive (${vm.inactiveCount})',
                      ],
                      selected: _filter,
                      onChanged: (i) => setState(() => _filter = i),
                    ),

                  ],

                  trailing: WebSearchField(
                      hint: 'Search name, username, address…',
                      onChanged: (v) => setState(() => _query = v),
                    ),

                ),
                const SizedBox(height: 16),
                if (vm.isLoading && vm.users.isEmpty)
                  const WebCard(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  _table(context, vm, rows),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _table(BuildContext context, ManageUsersViewModel vm, List<AppUser> rows) {
    final headers = _isClient
        ? ['Client', 'Address', 'Phone', 'Family', 'Status', '']
        : ['Caregiver', 'Phone', 'Address', 'Status', ''];
    final flex = _isClient ? [4, 5, 2, 1, 2, 1] : [4, 2, 5, 2, 1];

    return WebTable(
      headers: headers,
      flex: flex,
      onRowTap: (i) => _openForm(context, rows[i]),
      empty: WebEmptyState(
        icon: Icons.search_off,
        message: _query.isEmpty
            ? 'No ${_noun}s here yet'
            : 'No ${_noun}s match "$_query"',
      ),
      rows: [
        for (final u in rows)
          [
            _nameCell(u, vm.hasResetRequest(u)),
            if (_isClient) _text(u.address) else _text(u.phone),
            if (_isClient) _text(u.phone) else _text(u.address),
            if (_isClient) _text('${u.familyMemberIds.length}'),
            WebStatusBadge.active(u.isActive),
            Align(
              alignment: Alignment.centerRight,
              child: _actions(context, vm, u),
            ),
          ],
      ],
    );
  }

  Widget _nameCell(AppUser u, bool resetRequested) {
    return Row(
      children: [
        WebAvatar(name: u.fullName, photoUrl: u.photoUrl),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                u.fullName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '@${u.username}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        if (resetRequested) ...[
          const SizedBox(width: 8),
          const Tooltip(
            message: 'Requested a password reset',
            child: WebStatusBadge(
                label: 'Reset requested', color: AppTheme.warningColor),
          ),
        ],
      ],
    );
  }

  Widget _text(String v) => Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Text(
          v.isEmpty ? '—' : v,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
        ),
      );

  Widget _actions(BuildContext context, ManageUsersViewModel vm, AppUser u) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_horiz, color: AppTheme.textSecondary),
      onSelected: (v) {
        switch (v) {
          case 'edit':
            _openForm(context, u);
          case 'reports':
            _openReports(context, u);
          case 'reset':
            _resetPassword(context, u);
          case 'toggle':
            _toggleActive(context, vm, u);
          case 'delete':
            _delete(context, vm, u);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.edit_outlined, size: 18),
            title: Text('Edit'),
          ),
        ),
        if (_isClient && enabledWebSections.contains(WebSection.reports))
          const PopupMenuItem(
            value: 'reports',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.description_outlined, size: 18),
              title: Text('Shift reports'),
            ),
          ),
        const PopupMenuItem(
          value: 'reset',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.key_outlined, size: 18),
            title: Text('Reset password'),
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: ListTile(
            dense: true,
            leading: Icon(
              u.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
              size: 18,
            ),
            title: Text(u.isActive ? 'Deactivate' : 'Activate'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            dense: true,
            leading:
                Icon(Icons.delete_outline, size: 18, color: AppTheme.errorColor),
            title: Text('Delete',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ),
      ],
    );
  }

  void _openReports(BuildContext context, AppUser client) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(32),
        backgroundColor: WebTokens.pageBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 900),
          child: Stack(
            children: [
              WebReportsPage(clientId: client.uid, clientName: client.fullName),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, [AppUser? user]) async {
    final saved = await showWebUserForm(context, role: widget.role, user: user);
    if (saved) await _loadAll();
  }

  Future<void> _toggleActive(
      BuildContext context, ManageUsersViewModel vm, AppUser u) async {
    final deactivate = u.isActive;
    final ok = await webConfirm(
      context,
      title: deactivate ? 'Deactivate ${u.fullName}?' : 'Activate ${u.fullName}?',
      message: deactivate
          ? 'They will be signed out and won\'t be able to use the app until reactivated.'
          : 'They will be able to sign in again.',
      confirmLabel: deactivate ? 'Deactivate' : 'Activate',
      destructive: deactivate,
    );
    if (!ok) return;
    final success = await vm.toggleUserActive(u);
    if (context.mounted) {
      webToast(
        context,
        success
            ? '${u.fullName} ${deactivate ? 'deactivated' : 'activated'}'
            : 'Could not update ${u.fullName}',
        error: !success,
      );
    }
  }

  Future<void> _delete(
      BuildContext context, ManageUsersViewModel vm, AppUser u) async {
    final ok = await webConfirm(
      context,
      title: 'Delete ${u.fullName}?',
      message:
          'This removes all of their assignments and files and closes the account${_isClient ? ' and its family member logins' : ''}. This cannot be undone. To keep their schedule, deactivate instead.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    final success = await vm.deleteUser(u);
    if (context.mounted) {
      webToast(
        context,
        success ? '${u.fullName} deleted' : 'Could not delete ${u.fullName}',
        error: !success,
      );
    }
  }

  Future<void> _resetPassword(BuildContext context, AppUser u) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Reset password for ${u.fullName}'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New password',
              helperText: 'At least 6 characters',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.length >= 6) {
                Navigator.pop(ctx, controller.text);
              }
            },
            child: const Text('Reset password'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (password == null) return;
    try {
      await AuthService().resetUserPassword(uid: u.uid, newPassword: password);
      await _loadAll();
      if (context.mounted) {
        webToast(context, 'Password reset for ${u.fullName}');
      }
    } catch (e) {
      if (context.mounted) {
        webToast(context, 'Could not reset password: $e', error: true);
      }
    }
  }
}
