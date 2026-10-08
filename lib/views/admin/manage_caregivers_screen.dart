import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/manage_users_viewmodel.dart';
import '../../widgets/custom_loader.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/user_list_controls.dart';
import 'client_schedule_screen.dart';
import 'create_user_screen.dart';
import 'edit_user_screen.dart';

class ManageCaregiverScreen extends StatelessWidget {
  /// 'all' | 'active' | 'inactive', e.g. when opened from a dashboard card.
  final String initialFilter;

  /// Pushed on its own (with a back button) rather than shown as a tab.
  final bool standalone;

  const ManageCaregiverScreen({
    super.key,
    this.initialFilter = 'all',
    this.standalone = false,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ManageUsersViewModel(
        role: 'caregiver',
        initialFilter: initialFilter,
      )..loadAllUsers(),
      child: _ManageCaregiversBody(standalone: standalone),
    );
  }
}

class _ManageCaregiversBody extends StatelessWidget {
  final bool standalone;
  const _ManageCaregiversBody({this.standalone = false});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ManageUsersViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Caregivers'),
        automaticallyImplyLeading: standalone,
      ),
      body: _buildBody(context, vm),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addCaregiver',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateUserScreen(userType: 'Caregiver'),
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
        message: 'Loading caregivers...',
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
                color: AppTheme.successColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.medical_services_outlined,
                size: 40,
                color: AppTheme.successColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No caregivers yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap the button below to add your first caregiver',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final visible = vm.visibleUsers;
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
            UserListControls(vm: vm, searchHint: 'Search caregivers by name, phone…'),
            const SizedBox(height: 20),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No matches',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            // User cards
            ...List.generate(visible.length + (vm.isLoadingMore ? 1 : 0), (index) {
              if (index == visible.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return _UserCard(
                user: visible[index],
                vm: vm,
                userType: 'Caregiver',
              );
            }),
          ],
        ),
      ),
    );
  }
}


class _UserCard extends StatelessWidget {
  final AppUser user;
  final ManageUsersViewModel vm;
  final String userType;

  const _UserCard({
    required this.user,
    required this.vm,
    required this.userType,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = user.isActive;
    final hasResetRequest = vm.hasResetRequest(user);

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
                      onTap: () => _dismissResetRequest(context),
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
                  backgroundColor: AppTheme.successColor.withValues(
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
                            color: AppTheme.successColor,
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
            const SizedBox(height: 14),
            // Reset password button (shown when requested, or always available)
            if (hasResetRequest) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showResetPasswordDialog(context),
                  icon: const Icon(Icons.lock_reset, size: 18),
                  label: const Text(
                    'Reset Password',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditUserScreen(user: user),
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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ClientScheduleScreen.forCaregiver(caregiver: user),
                  ),
                ),
                icon: const Icon(Icons.calendar_month, size: 18),
                label: const Text(
                  'Schedule',
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
                    onPressed: () => _toggleStatus(context),
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
                    onPressed: () => _deleteUser(context),
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

  Future<void> _showResetPasswordDialog(BuildContext context) async {
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

  Future<void> _dismissResetRequest(BuildContext context) async {
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

  Future<void> _deleteUser(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete $userType'),
        content: Text(
          'Are you sure you want to permanently delete ${user.fullName}?\n\n'
          'This will remove all their data including assignments, profile, '
          'and authentication. This action cannot be undone.',
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

  Future<void> _toggleStatus(BuildContext context) async {
    final newStatus = !user.isActive;
    final action = newStatus ? 'activate' : 'deactivate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${newStatus ? 'Activate' : 'Deactivate'} $userType'),
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
        message: '${user.fullName} ${newStatus ? 'activated' : 'deactivated'}.',
      );
    } else {
      CustomSnackbar.error(
        context: context,
        message: 'Failed to update status.',
      );
    }
  }
}
