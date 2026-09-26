import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_user.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/user_avatar.dart';
import 'policy_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AppUser user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingPhoto = false;

  AppUser get user => context.watch<AuthViewModel>().currentUser ?? widget.user;

  Future<void> _pickAndUploadPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Update Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: AppTheme.primaryColor),
                ),
                title: const Text('Camera',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Take a new photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library,
                      color: AppTheme.successColor),
                ),
                title: const Text('Gallery',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      await context.read<AuthViewModel>().updateProfilePhoto(File(picked.path));
      UserAvatar.clearUser(user.uid);
      if (mounted) {
        CustomSnackbar.success(
          context: context,
          message: 'Profile photo updated!',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.error(
          context: context,
          message: 'Failed to update photo: $e',
        );
      }
    }
    if (mounted) setState(() => _isUploadingPhoto = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 270,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Account'),
                  _Section(
                    children: [
                      _InfoTile(
                          icon: Icons.person_outline,
                          label: 'Username',
                          value: user.username),
                      if (user.address.isNotEmpty)
                        _InfoTile(
                            icon: Icons.home_outlined,
                            label: 'Address',
                            value: user.address),
                      if (user.emergencyContact.isNotEmpty)
                        _InfoTile(
                            icon: Icons.emergency_outlined,
                            label: 'Emergency Contact',
                            value: user.emergencyContact),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (user.role == 'admin') ...[
                    const _SectionTitle('App'),
                    _Section(
                      children: [
                        _LinkTile(
                          icon: Icons.privacy_tip_outlined,
                          iconColor: AppTheme.primaryColor,
                          label: 'Privacy Policy',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PolicyScreen(
                                title: 'Privacy Policy',
                                intro: kPrivacyIntro,
                                lastUpdated: 'July 20, 2026',
                                sections: kPrivacySections,
                              ),
                            ),
                          ),
                        ),
                        const _TileDivider(),
                        _LinkTile(
                          icon: Icons.description_outlined,
                          iconColor: AppTheme.secondaryColor,
                          label: 'Terms of Service',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PolicyScreen(
                                title: 'Terms of Service',
                                intro: kTermsIntro,
                                lastUpdated: 'July 20, 2026',
                                sections: kTermsSections,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const _SectionTitle('About & Legal'),
                    _Section(
                      children: [
                        _LinkTile(
                          icon: Icons.privacy_tip_outlined,
                          iconColor: AppTheme.primaryColor,
                          label: 'Privacy Policy',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PolicyScreen(
                                title: 'Privacy Policy',
                                intro: kPrivacyIntro,
                                lastUpdated: 'July 20, 2026',
                                sections: kPrivacySections,
                              ),
                            ),
                          ),
                        ),
                        const _TileDivider(),
                        _LinkTile(
                          icon: Icons.description_outlined,
                          iconColor: AppTheme.secondaryColor,
                          label: 'Terms of Service',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PolicyScreen(
                                title: 'Terms of Service',
                                intro: kTermsIntro,
                                lastUpdated: 'July 20, 2026',
                                sections: kTermsSections,
                              ),
                            ),
                          ),
                        ),
                        const _TileDivider(),
                        _LinkTile(
                          icon: Icons.support_agent_outlined,
                          iconColor: AppTheme.successColor,
                          label: 'Contact Support',
                          onTap: () => _showEmailDialog(
                            context,
                            title: 'Contact Support',
                            message:
                                'For help with your account or the app, email us at:',
                            emailSubject: 'Mega Homecare Inc — Support Request',
                          ),
                        ),
                        const _TileDivider(),
                        _LinkTile(
                          icon: Icons.delete_outline,
                          iconColor: AppTheme.errorColor,
                          labelColor: AppTheme.errorColor,
                          label: 'Request Account Deletion',
                          onTap: () => _showEmailDialog(
                            context,
                            title: 'Request Account Deletion',
                            message:
                                'To delete your account and all associated data, contact your administrator or email:',
                            footer:
                                'Deletion requests are processed within 30 days.',
                            emailSubject:
                                'Mega Homecare Inc — Account Deletion Request',
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 28),

                  // Logout
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: () => _confirmLogout(context),
                      icon: const Icon(Icons.logout, size: 20),
                      label: const Text(
                        'Log Out',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            AppTheme.errorColor.withValues(alpha: 0.1),
                        foregroundColor: AppTheme.errorColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Mega Homecare Inc  •  Version 0.1.0',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final roleLabel = user.role.isNotEmpty
        ? user.role[0].toUpperCase() + user.role.substring(1)
        : '';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 30),
            GestureDetector(
              onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6), width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 46,
                      backgroundColor: Colors.white24,
                      backgroundImage: user.photoUrl.isNotEmpty
                          ? NetworkImage(user.photoUrl)
                          : null,
                      child: _isUploadingPhoto
                          ? const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)
                          : user.photoUrl.isEmpty
                              ? Text(
                                  user.fullName.isNotEmpty
                                      ? user.fullName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              user.fullName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                roleLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMailApp(BuildContext context, String subject) async {
    final uri = Uri(
      scheme: 'mailto',
      path: kSupportEmail,
      query: 'subject=${Uri.encodeComponent(subject)}',
    );
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('no mail app');
    } catch (_) {
      // No mail app configured — fall back to copying the address
      await Clipboard.setData(const ClipboardData(text: kSupportEmail));
      if (context.mounted) {
        CustomSnackbar.info(
          context: context,
          message: 'No mail app found. Email copied to clipboard.',
        );
      }
    }
  }

  void _showEmailDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String emailSubject,
    String? footer,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary)),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.mail_outline,
                      size: 18, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      kSupportEmail,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (footer != null) ...[
              const SizedBox(height: 12),
              Text(footer,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: kSupportEmail));
              Navigator.pop(ctx);
              CustomSnackbar.success(
                  context: context, message: 'Email copied to clipboard');
            },
            child: const Text('Copy'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _openMailApp(context, emailSubject);
            },
            icon: const Icon(Icons.mail_outline, size: 18),
            label: const Text('Email Us'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.popUntil(context, (route) => route.isFirst);
              context.read<AuthViewModel>().logout();
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final List<Widget> children;
  const _Section({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 62,
      endIndent: 16,
      color: Colors.grey.withValues(alpha: 0.15),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: AppTheme.primaryColor),
      ),
      title: Text(label,
          style: const TextStyle(
              fontSize: 12, color: AppTheme.textSecondary)),
      subtitle: Text(value,
          style: const TextStyle(
              fontSize: 15,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500)),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Color? labelColor;

  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(label,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: labelColor ?? AppTheme.textPrimary)),
      trailing: const Icon(Icons.chevron_right,
          size: 20, color: AppTheme.textSecondary),
      onTap: onTap,
    );
  }
}
