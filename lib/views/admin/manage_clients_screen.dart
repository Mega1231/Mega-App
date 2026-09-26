import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../services/assignment_service.dart';
import '../../services/auth_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/manage_users_viewmodel.dart';
import '../../widgets/custom_loader.dart';
import '../../widgets/custom_snackbar.dart';
import 'create_user_screen.dart';

class ManageClientsScreen extends StatelessWidget {
  const ManageClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ManageUsersViewModel(role: 'client')..loadUsers(),
      child: const _ManageClientsBody(),
    );
  }
}

class _ManageClientsBody extends StatelessWidget {
  const _ManageClientsBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ManageUsersViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Clients'),
        automaticallyImplyLeading: false,
      ),
      body: _buildBody(context, vm),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addClient',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateUserScreen(userType: 'Client'),
            ),
          );
          if (result == true) vm.refresh();
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ManageUsersViewModel vm) {
    if (vm.isLoading && vm.users.isEmpty) {
      return const CustomLoader(
        color: AppTheme.primaryColor,
        showMessage: true,
        message: 'Loading clients...',
      );
    }

    if (vm.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 40,
                color: AppTheme.primaryColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No clients yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap the button below to add your first client',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scroll) {
        if (scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 200 &&
            !vm.isLoadingMore &&
            vm.hasMore) {
          vm.loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: vm.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // Section header

            // Stats row
            _StatsRow(
              activeCount: vm.activeCount,
              totalCount: vm.totalCount,
              inactiveCount: vm.inactiveCount,
            ),
            const SizedBox(height: 20),
            // User cards
            ...List.generate(vm.users.length + (vm.hasMore ? 1 : 0), (index) {
              if (index == vm.users.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return _UserCard(
                user: vm.users[index],
                vm: vm,
                userType: 'Client',
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int activeCount;
  final int totalCount;
  final int inactiveCount;

  const _StatsRow({
    required this.activeCount,
    required this.totalCount,
    required this.inactiveCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            count: activeCount,
            label: 'Active',
            color: AppTheme.successColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            count: totalCount,
            label: 'Total',
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            count: inactiveCount,
            label: 'Inactive',
            color: AppTheme.errorColor,
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatBox({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatefulWidget {
  final AppUser user;
  final ManageUsersViewModel vm;
  final String userType;

  const _UserCard({
    required this.user,
    required this.vm,
    required this.userType,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _showFamily = false;
  List<AppUser>? _familyMembers;
  bool _loadingFamily = false;
  final AuthService _authService = AuthService();

  Future<void> _loadFamilyMembers() async {
    setState(() => _loadingFamily = true);
    _familyMembers = await _authService.getFamilyMembers(widget.user.uid);
    setState(() => _loadingFamily = false);
  }

  Future<void> _deleteFamilyMember(AppUser member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Family Member'),
        content: Text(
            'Are you sure you want to remove ${member.fullName}? This will delete their account permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _authService.deleteFamilyMember(member.uid, widget.user.uid);
      if (!mounted) return;
      CustomSnackbar.success(
        context: context,
        message: '${member.fullName} removed.',
      );
      _loadFamilyMembers();
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.error(
        context: context,
        message: 'Failed to remove family member.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final vm = widget.vm;
    final isActive = user.isActive;
    final familyCount = user.familyMemberIds.length;
    final hasResetRequest = widget.vm.hasResetRequest(user);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: hasResetRequest
            ? Border.all(color: AppTheme.warningColor.withValues(alpha: 0.4), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Password reset request banner
            if (hasResetRequest) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.warningColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_reset,
                        size: 16, color: AppTheme.warningColor),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Password reset requested',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _dismissResetRequest(context, user, vm),
                      child: Icon(Icons.close,
                          size: 16,
                          color: AppTheme.warningColor.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryColor.withValues(
                    alpha: 0.08,
                  ),
                  backgroundImage: user.photoUrl.isNotEmpty
                      ? NetworkImage(user.photoUrl)
                      : null,
                  child: user.photoUrl.isEmpty
                      ? Text(
                          user.fullName.isNotEmpty
                              ? user.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (user.address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.address,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                ),
              ],
            ),

            // Reset password button
            if (hasResetRequest) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showResetPasswordDialog(context, user, vm),
                  icon: const Icon(Icons.lock_reset, size: 18),
                  label: const Text(
                    'Reset Password',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.warningColor,
                    side: BorderSide(
                      color: AppTheme.warningColor.withValues(alpha: 0.4),
                    ),
                    backgroundColor:
                        AppTheme.warningColor.withValues(alpha: 0.06),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],

            // Family members toggle
            if (familyCount > 0) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  setState(() => _showFamily = !_showFamily);
                  if (_showFamily && _familyMembers == null) {
                    _loadFamilyMembers();
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.family_restroom,
                          size: 18,
                          color:
                              AppTheme.primaryColor.withValues(alpha: 0.7)),
                      const SizedBox(width: 8),
                      Text(
                        '$familyCount family member${familyCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              AppTheme.primaryColor.withValues(alpha: 0.8),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _showFamily
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 20,
                        color: AppTheme.primaryColor.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Family members list
            if (_showFamily) ...[
              if (_loadingFamily)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_familyMembers != null)
                ...(_familyMembers!.map((m) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppTheme.warningColor
                                  .withValues(alpha: 0.1),
                              child: Text(
                                m.fullName.isNotEmpty
                                    ? m.fullName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.warningColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.fullName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '@${m.username}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _deleteFamilyMember(m),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor
                                      .withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 14, color: AppTheme.errorColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ))),
            ],

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateUserScreen(
                        userType: 'Client',
                        existingUser: user,
                      ),
                    ),
                  );
                  if (result == true && context.mounted) {
                    vm.refresh();
                  }
                },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text(
                  'Edit Profile',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  ),
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _downloadClientSchedule(context, user),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text(
                  'Download Schedule',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  ),
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _toggleStatus(context, user, vm),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isActive
                          ? AppTheme.errorColor
                          : AppTheme.successColor,
                      side: BorderSide(
                        color: isActive
                            ? AppTheme.errorColor.withValues(alpha: 0.3)
                            : AppTheme.successColor.withValues(alpha: 0.3),
                      ),
                      backgroundColor: isActive
                          ? AppTheme.errorColor.withValues(alpha: 0.04)
                          : AppTheme.successColor.withValues(alpha: 0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      isActive ? 'Deactivate' : 'Activate',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? AppTheme.errorColor
                            : AppTheme.successColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteUser(context, user, vm),
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: BorderSide(
                        color: AppTheme.errorColor.withValues(alpha: 0.3),
                      ),
                      backgroundColor:
                          AppTheme.errorColor.withValues(alpha: 0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadClientSchedule(
      BuildContext context, AppUser user) async {
    try {
      CustomSnackbar.info(
        context: context,
        message: 'Generating schedule PDF...',
        showFromTop: true,
      );
      final assignments =
          await AssignmentService().getClientAssignments(user.uid);
      if (assignments.isEmpty) {
        if (context.mounted) {
          CustomSnackbar.warning(
            context: context,
            message: 'No active assignments found for ${user.fullName}.',
            showFromTop: true,
          );
        }
        return;
      }
      final filePath = await PdfService().generateClientSchedulePdf(
        clientName: user.fullName,
        assignments: assignments,
      );
      await OpenFile.open(filePath);
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.error(
          context: context,
          message: 'Failed to generate PDF: $e',
          showFromTop: true,
        );
      }
    }
  }

  Future<void> _showResetPasswordDialog(
      BuildContext context, AppUser user, ManageUsersViewModel vm) async {
    final newPassCtrl = TextEditingController();
    bool isResetting = false;
    bool obscureNew = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Reset Password for ${user.fullName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter a new password for this user.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPassCtrl,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_reset,
                      color: AppTheme.primaryColor),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setDialogState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isResetting
                  ? null
                  : () async {
                      if (newPassCtrl.text.isEmpty) {
                        CustomSnackbar.warning(
                          context: context,
                          message: 'Please enter a new password.',
                        );
                        return;
                      }
                      if (newPassCtrl.text.length < 6) {
                        CustomSnackbar.warning(
                          context: context,
                          message:
                              'Password must be at least 6 characters.',
                        );
                        return;
                      }

                      setDialogState(() => isResetting = true);

                      try {
                        await AuthService().resetUserPassword(
                          uid: user.uid,
                          newPassword: newPassCtrl.text,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setDialogState(() => isResetting = false);
                        if (context.mounted) {
                          CustomSnackbar.error(
                            context: context,
                            message: 'Failed to reset password. Try again.',
                          );
                        }
                      }
                    },
              child: isResetting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Reset Password'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      CustomSnackbar.success(
        context: context,
        message: 'Password reset for ${user.fullName}.',
      );
      vm.refresh();
    }
  }

  Future<void> _dismissResetRequest(
      BuildContext context, AppUser user, ManageUsersViewModel vm) async {
    try {
      await AuthService().clearPasswordResetRequest(user.username);
      if (context.mounted) {
        CustomSnackbar.info(
          context: context,
          message: 'Reset request dismissed.',
        );
        vm.refresh();
      }
    } catch (_) {}
  }

  Future<void> _deleteUser(
      BuildContext context, AppUser user, ManageUsersViewModel vm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Client'),
        content: Text(
          'Are you sure you want to delete ${user.fullName}?\n\n'
          'This will deactivate their account, remove all assignments, '
          'and delete their files. They will no longer be able to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success = await vm.deleteUser(user);
    if (!context.mounted) return;

    if (success) {
      CustomSnackbar.success(
        context: context,
        message: '${user.fullName} has been deleted.',
      );
    } else {
      CustomSnackbar.error(
        context: context,
        message: 'Failed to delete ${user.fullName}.',
      );
    }
  }

  Future<void> _toggleStatus(
      BuildContext context, AppUser user, ManageUsersViewModel vm) async {
    final newStatus = !user.isActive;
    final action = newStatus ? 'activate' : 'deactivate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
            '${newStatus ? 'Activate' : 'Deactivate'} ${widget.userType}'),
        content: Text('Are you sure you want to $action ${user.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              newStatus ? 'Activate' : 'Deactivate',
              style: TextStyle(
                color: newStatus ? AppTheme.successColor : AppTheme.errorColor,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success = await vm.toggleUserActive(user);
    if (!context.mounted) return;

    if (success) {
      CustomSnackbar.success(
        context: context,
        message:
            '${user.fullName} ${newStatus ? 'activated' : 'deactivated'}.',
      );
    } else {
      CustomSnackbar.error(
        context: context,
        message: 'Failed to update status.',
      );
    }
  }
}
