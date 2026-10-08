import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/application_service.dart';
import '../../theme/app_theme.dart';
import '../web_widgets.dart';

/// Applicant documents sit behind a separate "documents password" that
/// Becky can change. These dialogs unlock it (30 minutes per unlock), set it
/// the first time, change it, or reset it after signing in again.

/// Makes sure the vault is unlocked; returns false if the admin cancelled.
Future<bool> ensureVaultUnlocked(BuildContext context) async {
  if (ApplicationService.vaultToken != null) return true;
  final service = ApplicationService();
  final bool isSet;
  try {
    isSet = await service.vaultIsSet();
  } catch (e) {
    if (context.mounted) {
      webToast(context, ApplicationService.errorText(e), error: true);
    }
    return false;
  }
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => isSet ? const _UnlockDialog() : const VaultPasswordDialog(),
  );
  return ok == true;
}

/// Opens the right "documents password" dialog: create, or change/reset.
Future<void> showVaultSettings(BuildContext context) async {
  final bool isSet;
  try {
    isSet = await ApplicationService().vaultIsSet();
  } catch (e) {
    if (context.mounted) {
      webToast(context, ApplicationService.errorText(e), error: true);
    }
    return;
  }
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => VaultPasswordDialog(changing: isSet),
  );
  if (ok == true && context.mounted) {
    webToast(
      context,
      isSet ? 'Documents password changed' : 'Documents password created',
    );
  }
}

InputDecoration _dec(String label, {String? helper}) =>
    InputDecoration(labelText: label, helperText: helper, helperMaxLines: 2);

class _UnlockDialog extends StatefulWidget {
  const _UnlockDialog();

  @override
  State<_UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<_UnlockDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApplicationService().unlockVault(_password.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = ApplicationService.errorText(e);
      });
    }
  }

  Future<void> _forgot() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const VaultPasswordDialog(resetting: true),
    );
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Row(
        children: [
          Icon(Icons.lock_outline, color: AppTheme.primaryColor),
          SizedBox(width: 10),
          Text('Documents password'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Applicant documents are protected. Enter the documents password to view them for the next 30 minutes.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              autofocus: true,
              decoration: _dec('Documents password'),
              onSubmitted: (_) => _unlock(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppTheme.errorColor,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _forgot,
          child: const Text('Forgot password?'),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _unlock,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Unlock'),
        ),
      ],
    );
  }
}

/// Create (first time), change (needs the current documents password) or
/// reset (needs the admin's login password instead).
class VaultPasswordDialog extends StatefulWidget {
  final bool changing;
  final bool resetting;

  const VaultPasswordDialog({
    super.key,
    this.changing = false,
    this.resetting = false,
  });

  @override
  State<VaultPasswordDialog> createState() => _VaultPasswordDialogState();
}

class _VaultPasswordDialogState extends State<VaultPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _login = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  late bool _resetting = widget.resetting;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_current, _login, _new, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_resetting) {
        // Signing in again proves it's the admin; the server accepts a reset
        // for 5 minutes after a fresh sign-in.
        final user = FirebaseAuth.instance.currentUser!;
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(
            email: user.email!,
            password: _login.text,
          ),
        );
        await user.getIdToken(true);
      }
      await ApplicationService().setVaultPassword(
        currentPassword: widget.changing && !_resetting ? _current.text : null,
        newPassword: _new.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _busy = false;
        _error = e.code == 'wrong-password' || e.code == 'invalid-credential'
            ? 'Your login password is incorrect.'
            : e.message ?? 'Could not verify your login.';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = ApplicationService.errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _resetting
        ? 'Reset documents password'
        : widget.changing
        ? 'Change documents password'
        : 'Create documents password';
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _resetting
                    ? 'Enter the password you use to sign in to the admin panel, then choose a new documents password.'
                    : widget.changing
                    ? 'Anyone who opens applicant documents will need the new password.'
                    : 'Choose a password for opening applicant documents. It is separate from your login password.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              if (_resetting) ...[
                TextFormField(
                  controller: _login,
                  obscureText: true,
                  decoration: _dec('Your login password'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
              ] else if (widget.changing) ...[
                TextFormField(
                  controller: _current,
                  obscureText: true,
                  decoration: _dec('Current documents password'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _resetting = true),
                    child: const Text('Forgot it?'),
                  ),
                ),
              ],
              TextFormField(
                controller: _new,
                obscureText: true,
                decoration: _dec(
                  'New documents password',
                  helper: 'At least 6 characters',
                ),
                validator: (v) =>
                    v == null || v.length < 6 ? 'At least 6 characters' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: _dec('Confirm new password'),
                validator: (v) =>
                    v != _new.text ? 'Passwords do not match' : null,
                onFieldSubmitted: (_) => _save(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppTheme.errorColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
