import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/caregiver_application.dart';
import '../../services/application_service.dart';
import '../../services/download/file_download.dart';
import '../../theme/app_theme.dart';
import '../apply/letter_body.dart';
import '../web_widgets.dart';
import 'web_documents_vault.dart';

/// Stage 2 on the admin review page (accepted applications): fill in the
/// offer details, send the five letters, follow signing, open the signed
/// PDFs and create the caregiver's app login.
class OnboardingCard extends StatefulWidget {
  final ApplicationRecord app;
  final ValueChanged<ApplicationRecord> onUpdated;
  final VoidCallback onReload;

  const OnboardingCard({
    super.key,
    required this.app,
    required this.onUpdated,
    required this.onReload,
  });

  @override
  State<OnboardingCard> createState() => _OnboardingCardState();
}

class _OnboardingCardState extends State<OnboardingCard> {
  final _service = ApplicationService();
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController();
  late final _position = TextEditingController();
  late final _payRate = TextEditingController();
  late final _schedule = TextEditingController();
  late final _startDate = TextEditingController();
  late final _jobDescription = TextEditingController();
  bool _editing = false;
  bool _sendEmail = true;
  String? _busy;

  AdminOnboarding get _ob => widget.app.onboarding;

  @override
  void initState() {
    super.initState();
    _fill();
  }

  @override
  void didUpdateWidget(OnboardingCard old) {
    super.didUpdateWidget(old);
    if (old.app.onboarding.sentAt != widget.app.onboarding.sentAt) _fill();
  }

  void _fill() {
    final f = _ob.fields;
    _name.text = f?.fullName ?? widget.app.fullName;
    _position.text = f?.position ?? _ob.defaultPosition;
    _payRate.text = f?.payRate ?? '';
    _schedule.text = f?.schedule ?? '';
    _startDate.text = f?.startDate ?? '';
    _jobDescription.text = f?.jobDescription ?? _ob.defaultJobDescription;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _position,
      _payRate,
      _schedule,
      _startDate,
      _jobDescription,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  OnboardingFields get _fields => OnboardingFields(
    fullName: _name.text.trim(),
    position: _position.text.trim(),
    payRate: _payRate.text.trim(),
    schedule: _schedule.text.trim(),
    startDate: _startDate.text.trim(),
    jobDescription: _jobDescription.text.trim(),
  );

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    DateTime? initial;
    try {
      initial = DateFormat('MMMM d, y').parseLoose(_startDate.text);
    } catch (_) {}
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _startDate.text = DateFormat('MMMM d, y').format(picked));
    }
  }

  Future<void> _preview() async {
    setState(() => _busy = 'preview');
    try {
      final r = await _service.previewLetters(_fields);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => _PreviewDialog(letters: r.letters, missing: r.missing),
      );
    } catch (e) {
      if (mounted) {
        webToast(context, ApplicationService.errorText(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final resend = _ob.status == OnboardingStatus.sent;
    final ok = await webConfirm(
      context,
      title: resend
          ? 'Update the documents?'
          : 'Send the documents to ${_name.text.trim()}?',
      message: [
        'They will see the 5 documents on their application link and sign each one.',
        if (_sendEmail && widget.app.email.isNotEmpty)
          'An email goes to ${widget.app.email}, with reminders every 4 hours (8 am – 10 pm) until everything is signed.',
        if (widget.app.email.isEmpty)
          'They have no email, so share the link yourself (Copy / WhatsApp).',
      ].join('\n\n'),
      confirmLabel: resend ? 'Update' : 'Send documents',
    );
    if (!ok) return;
    setState(() => _busy = 'send');
    try {
      final r = await _service.sendLetters(
        widget.app,
        _fields,
        sendEmail: _sendEmail && widget.app.email.isNotEmpty,
      );
      if (!mounted) return;
      widget.onUpdated(r.app);
      setState(() => _editing = false);
      webToast(
        context,
        r.emailSent
            ? 'Documents sent — ${widget.app.email} was emailed'
            : 'Documents are ready on their link. Share it with WhatsApp or a text message.',
      );
    } catch (e) {
      if (mounted) {
        webToast(context, ApplicationService.errorText(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _viewSigned(OnboardingLetter l) async {
    if (!await ensureVaultUnlocked(context) || !mounted) return;
    setState(() => _busy = 'view-${l.id}');
    try {
      final file = await _service.getSignedLetter(widget.app.id, l.id);
      await openFileInBrowser(
        file.bytes,
        file.fileName,
        mimeType: file.contentType,
      );
    } on VaultLockedException {
      if (mounted && await ensureVaultUnlocked(context) && mounted) {
        setState(() => _busy = null);
        return _viewSigned(l);
      }
    } catch (e) {
      if (mounted) {
        webToast(context, ApplicationService.errorText(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _createLogin() async {
    final created = await showDialog<({String username, String password})>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateLoginDialog(
        applicationId: widget.app.id,
        fullName: _ob.fields?.fullName ?? widget.app.fullName,
      ),
    );
    if (created == null || !mounted) return;
    widget.onReload();
    await showDialog(
      context: context,
      builder: (_) => _LoginCreatedDialog(
        fullName: _ob.fields?.fullName ?? widget.app.fullName,
        username: created.username,
        password: created.password,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ob = _ob;
    final showForm =
        ob.status == OnboardingStatus.notSent ||
        (_editing && ob.status == OnboardingStatus.sent && ob.signedCount == 0);
    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.draw_outlined, color: AppTheme.primaryColor),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Onboarding documents',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (ob.status != OnboardingStatus.notSent)
                WebStatusBadge(
                  label: ob.loginCreated
                      ? 'Login created'
                      : ob.status == OnboardingStatus.completed
                      ? 'All signed'
                      : '${ob.signedCount} of ${ob.letters.length} signed',
                  color: ob.status == OnboardingStatus.completed
                      ? AppTheme.successColor
                      : AppTheme.primaryColor,
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (showForm) _form() else _progress(),
        ],
      ),
    );
  }

  Widget _form() {
    Widget field(
      TextEditingController c,
      String label, {
      String? hint,
      int lines = 1,
      bool required = true,
      VoidCallback? onTap,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 3,
        readOnly: onTap != null,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: lines > 1,
          suffixIcon: onTap != null
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : null,
        ),
        validator: required
            ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
            : null,
      ),
    );
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Fill in the Offer Letter details. The full name goes into all 5 documents; the caregiver then signs each one on their link.',
            style: TextStyle(
              fontSize: 13.5,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final two = c.maxWidth > 560;
              final name = field(_name, 'Caregiver full name');
              final position = field(
                _position,
                'Position title',
                hint: 'e.g. Caregiver, PSW',
              );
              final pay = field(
                _payRate,
                'Pay rate',
                hint: r'e.g. $20.00/hour',
              );
              final start = field(
                _startDate,
                'Start date',
                onTap: _pickStartDate,
              );
              if (!two) return Column(children: [name, position, pay, start]);
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: name),
                      const SizedBox(width: 12),
                      Expanded(child: position),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: pay),
                      const SizedBox(width: 12),
                      Expanded(child: start),
                    ],
                  ),
                ],
              );
            },
          ),
          field(_schedule, 'Schedule', hint: 'e.g. Mon–Fri, 9:00am–5:00pm'),
          field(_jobDescription, 'Job description (Offer Letter)', lines: 3),
          if (widget.app.email.isNotEmpty)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _sendEmail,
              onChanged: (v) => setState(() => _sendEmail = v == true),
              title: Text(
                'Email ${widget.app.email} that the documents are ready',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 10,
            children: [
              if (_editing)
                TextButton(
                  onPressed: _busy != null
                      ? null
                      : () => setState(() {
                          _editing = false;
                          _fill();
                        }),
                  child: const Text('Cancel'),
                ),
              OutlinedButton.icon(
                onPressed: _busy != null ? null : _preview,
                icon: _busy == 'preview'
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Preview documents'),
              ),
              FilledButton.icon(
                onPressed: _busy != null ? null : _send,
                icon: _busy == 'send'
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, size: 18),
                label: Text(_editing ? 'Update documents' : 'Send documents'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progress() {
    final ob = _ob;
    final f = ob.fields;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (f != null)
          Text(
            [
              f.fullName,
              f.position,
              f.payRate,
              f.schedule,
              'starts ${f.startDate}',
            ].where((e) => e.isNotEmpty).join(' · '),
            style: const TextStyle(
              fontSize: 13.5,
              color: AppTheme.textSecondary,
            ),
          ),
        if (ob.sentAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Sent ${DateFormat('MMM d, h:mm a').format(ob.sentAt!)}'
              '${ob.completedAt != null ? ' · all signed ${DateFormat('MMM d, h:mm a').format(ob.completedAt!)}' : ''}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        const SizedBox(height: 12),
        for (final l in ob.letters)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: WebTokens.border),
            ),
            child: Row(
              children: [
                Icon(
                  l.isSigned ? Icons.check_circle : Icons.schedule,
                  size: 20,
                  color: l.isSigned
                      ? AppTheme.successColor
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        l.isSigned
                            ? 'Signed ${DateFormat('MMM d, h:mm a').format(l.signedAt!)}'
                            : 'Waiting for signature',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: l.isSigned
                              ? AppTheme.successColor
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_busy == 'view-${l.id}')
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (l.isSigned)
                  TextButton.icon(
                    onPressed: _busy != null ? null : () => _viewSigned(l),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Signed PDF'),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        if (ob.loginCreated)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'App login created: @${ob.caregiverUsername}. They now appear under Caregivers.',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else if (ob.status == OnboardingStatus.completed)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.successColor,
            ),
            onPressed: _busy != null ? null : _createLogin,
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('Create caregiver login'),
          )
        else
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              const Text(
                'Waiting for the caregiver to sign on their link.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              if (ob.signedCount == 0)
                TextButton.icon(
                  onPressed: _busy != null
                      ? null
                      : () => setState(() => _editing = true),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit details'),
                ),
            ],
          ),
      ],
    );
  }
}

class _PreviewDialog extends StatefulWidget {
  final List<OnboardingLetter> letters;
  final List<String> missing;

  const _PreviewDialog({required this.letters, required this.missing});

  @override
  State<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<_PreviewDialog> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: min(860, size.width * 0.9),
        height: size.height * 0.88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Preview — what the caregiver will sign',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (widget.missing.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Not filled in yet: ${widget.missing.join(', ')}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: WebFilterTabs(
                  labels: widget.letters.map((l) => l.title).toList(),
                  selected: _index,
                  onChanged: (i) => setState(() => _index = i),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: WebTokens.border),
            Expanded(
              child: Container(
                color: WebTokens.pageBg,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: WebCard(
                        padding: const EdgeInsets.all(28),
                        child: LetterBody(letter: widget.letters[_index]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _suggestUsername(String fullName) {
  final parts =
      fullName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z\s]'), '')
          .split(RegExp(r'\s+'))
        ..removeWhere((p) => p.isEmpty);
  if (parts.isEmpty) return '';
  return parts.length == 1 ? parts.first : '${parts.first}${parts.last[0]}';
}

String _suggestPassword() {
  const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = Random.secure();
  return List.generate(10, (_) => chars[r.nextInt(chars.length)]).join();
}

class _CreateLoginDialog extends StatefulWidget {
  final String applicationId;
  final String fullName;

  const _CreateLoginDialog({
    required this.applicationId,
    required this.fullName,
  });

  @override
  State<_CreateLoginDialog> createState() => _CreateLoginDialogState();
}

class _CreateLoginDialogState extends State<_CreateLoginDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _username = TextEditingController(
    text: _suggestUsername(widget.fullName),
  );
  late final _password = TextEditingController(text: _suggestPassword());
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final username = await ApplicationService().createLogin(
        widget.applicationId,
        username: _username.text.trim().toLowerCase(),
        password: _password.text,
      );
      if (mounted) {
        Navigator.pop(context, (username: username, password: _password.text));
      }
    } catch (e) {
      setState(() {
        _busy = false;
        _error = ApplicationService.errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text('App login for ${widget.fullName}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Creates their caregiver account in the Mega Homecare app. Their phone and emergency contact come from the application.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixText: '@',
                ),
                validator: (v) =>
                    RegExp(
                      r'^[a-z0-9._-]{3,30}$',
                    ).hasMatch((v ?? '').trim().toLowerCase())
                    ? null
                    : '3–30 letters or numbers (no spaces)',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    tooltip: 'New password',
                    icon: const Icon(Icons.refresh),
                    onPressed: () =>
                        setState(() => _password.text = _suggestPassword()),
                  ),
                ),
                validator: (v) =>
                    (v ?? '').length < 6 ? 'At least 6 characters' : null,
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
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Create login'),
        ),
      ],
    );
  }
}

class _LoginCreatedDialog extends StatelessWidget {
  final String fullName;
  final String username;
  final String password;

  const _LoginCreatedDialog({
    required this.fullName,
    required this.username,
    required this.password,
  });

  String get _message {
    final first = fullName.trim().split(RegExp(r'\s+')).first;
    return 'Hi $first, welcome to Mega Homecare! Please download the Mega Homecare app and sign in with:\n'
        'Username: $username\nPassword: $password\n'
        'You can see your schedule, clock in and send your shift reports in the app.';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Login created'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share these with $fullName. The password is shown only now.',
              style: const TextStyle(
                fontSize: 13.5,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: WebTokens.pageBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: WebTokens.border),
              ),
              child: SelectableText(
                'Username: $username\nPassword: $password',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _message));
            if (context.mounted) webToast(context, 'Message copied');
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copy message'),
        ),
        TextButton.icon(
          // WhatsApp asks which chat to send to; phone formats vary too much
          // to pre-pick the contact.
          onPressed: () => launchUrl(
            Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_message)}'),
            webOnlyWindowName: '_blank',
          ),
          icon: const Icon(Icons.chat_outlined, size: 18),
          label: const Text('WhatsApp'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
