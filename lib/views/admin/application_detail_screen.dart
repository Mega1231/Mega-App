import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/caregiver_application.dart';
import '../../services/application_service.dart';
import '../../services/download/file_download.dart';
import '../../theme/app_theme.dart';
import '../../web/pages/web_documents_vault.dart';
import '../../web/pages/web_onboarding_card.dart';
import '../../web/web_widgets.dart' show webConfirm;
import '../../widgets/comment_dialog.dart';
import 'applications_screen.dart';

/// One application on the mobile admin app: review documents, send back,
/// accept or reject, then the onboarding documents and the app login.
class ApplicationDetailScreen extends StatefulWidget {
  final String id;
  final String name;

  const ApplicationDetailScreen({
    super.key,
    required this.id,
    required this.name,
  });

  @override
  State<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  final _service = ApplicationService();
  final _comment = TextEditingController();
  ApplicationRecord? _app;
  String? _error;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final app = await _service.get(widget.id);
      if (mounted) {
        setState(() {
          _app = app;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = ApplicationService.errorText(e));
    }
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppTheme.errorColor : null,
      ),
    );
  }

  Future<void> _run(
    String key,
    Future<ApplicationRecord?> Function() action, {
    String? done,
  }) async {
    setState(() => _busy = key);
    try {
      final updated = await action();
      if (!mounted) return;
      if (updated != null) setState(() => _app = updated);
      if (done != null) _toast(done);
    } catch (e) {
      if (mounted) _toast(ApplicationService.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  // ── Documents ──

  Future<void> _view(RequiredDocument d, {DocumentVersion? version}) async {
    if (!await ensureVaultUnlocked(context) || !mounted) return;
    setState(() => _busy = 'view-${d.id}');
    try {
      final file = await _service.getDocument(
        widget.id,
        d.id,
        storagePath: version?.storagePath,
      );
      if (!mounted) return;
      if ({
        'image/jpeg',
        'image/png',
        'image/webp',
      }.contains(file.contentType)) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => _ImageViewer(title: d.label, bytes: file.bytes),
          ),
        );
      } else {
        await openFileInBrowser(
          file.bytes,
          file.fileName,
          mimeType: file.contentType,
        );
      }
    } on VaultLockedException {
      if (mounted && await ensureVaultUnlocked(context) && mounted) {
        setState(() => _busy = null);
        return _view(d, version: version);
      }
    } catch (e) {
      if (mounted) _toast(ApplicationService.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<String?> _askComment(String title, {String initial = ''}) =>
      showCommentDialog(
        context,
        title: title,
        confirmLabel: 'Needs changes',
        hint: 'e.g. The photo is blurry, please take it again in good light',
        helper: 'The applicant sees this on their page and in the email.',
        initial: initial,
      );

  Future<void> _documentActions(RequiredDocument d) async {
    final app = _app!;
    final doc = app.doc(d.id);
    final reviewable =
        doc.hasFile &&
        app.status != ApplicationStatus.accepted &&
        app.status != ApplicationStatus.rejected;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                d.label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (doc.hasFile)
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('View'),
                subtitle: Text(doc.fileName),
                onTap: () => Navigator.pop(ctx, 'view'),
              ),
            if (reviewable && doc.status != DocStatus.approved)
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: AppTheme.successColor,
                ),
                title: const Text('Approve'),
                onTap: () => Navigator.pop(ctx, 'approve'),
              ),
            if (reviewable)
              ListTile(
                leading: const Icon(
                  Icons.edit_note,
                  color: AppTheme.warningColor,
                ),
                title: const Text('Needs changes'),
                subtitle: const Text('Add a comment for the applicant'),
                onTap: () => Navigator.pop(ctx, 'flag'),
              ),
            if (reviewable && doc.status != DocStatus.uploaded)
              ListTile(
                leading: const Icon(Icons.undo),
                title: const Text('Undo review'),
                onTap: () => Navigator.pop(ctx, 'undo'),
              ),
            for (final h in doc.history.reversed)
              ListTile(
                leading: const Icon(Icons.history),
                title: Text('Earlier upload: ${h.fileName}'),
                subtitle: Text(
                  [
                    if (h.uploadedAt != null)
                      DateFormat('MMM d, h:mm a').format(h.uploadedAt!),
                    if (h.comment.isNotEmpty) '"${h.comment}"',
                  ].join(' · '),
                ),
                onTap: () => Navigator.pop(ctx, 'history:${h.storagePath}'),
              ),
            if (!doc.hasFile)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Text(
                  'Not uploaded yet.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'view') return _view(d);
    if (action.startsWith('history:')) {
      final path = action.substring(8);
      return _view(
        d,
        version: doc.history.firstWhere((h) => h.storagePath == path),
      );
    }
    if (action == 'approve' || action == 'undo') {
      return _run(
        'doc-${d.id}',
        () => _service.reviewDocument(
          app,
          docType: d.id,
          decision: action == 'approve'
              ? DocStatus.approved
              : DocStatus.uploaded,
        ),
      );
    }
    final comment = await _askComment(
      'What needs to change?',
      initial: doc.comment,
    );
    if (comment == null) return;
    await _run(
      'doc-${d.id}',
      () => _service.reviewDocument(
        app,
        docType: d.id,
        decision: DocStatus.needsChanges,
        comment: comment,
      ),
    );
  }

  // ── Decision ──

  Future<void> _requestChanges() async {
    final app = _app!;
    final flagged = app.requiredDocuments
        .where((d) => app.doc(d.id).status == DocStatus.needsChanges)
        .toList();
    final ok = await webConfirm(
      context,
      title: 'Send back to ${app.fullName}?',
      message: [
        if (flagged.isNotEmpty)
          'To upload again: ${flagged.map((d) => d.label).join(', ')}.',
        if (_comment.text.trim().isNotEmpty) 'Comment: ${_comment.text.trim()}',
        app.email.isNotEmpty
            ? 'They will get an email at ${app.email} with your notes, and reminders until they submit again.'
            : 'They have no email, so send them the link yourself.',
      ].join('\n\n'),
      confirmLabel: 'Send back',
    );
    if (!ok) return;
    setState(() => _busy = 'request');
    try {
      final r = await _service.decide(
        app,
        decision: 'request_changes',
        comment: _comment.text.trim(),
      );
      if (!mounted) return;
      setState(() => _app = r.app);
      _comment.clear();
      _toast(
        r.emailSent
            ? 'Sent back — ${app.email} was emailed'
            : 'Sent back. Please share the link yourself.',
        error: !r.emailSent && app.email.isNotEmpty,
      );
    } catch (e) {
      if (mounted) _toast(ApplicationService.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _decide(String decision) async {
    final app = _app!;
    final (title, message, label, destructive) = switch (decision) {
      'accept' => (
        'Accept ${app.fullName}?',
        'Next come the onboarding documents.',
        'Accept',
        false,
      ),
      'reject' => (
        'Reject ${app.fullName}?',
        'Their link will close. No email is sent — let them know yourself if needed.',
        'Reject',
        true,
      ),
      _ => (
        'Re-open for review?',
        'The application goes back to "Ready for review".',
        'Re-open',
        false,
      ),
    };
    if (!await webConfirm(
      context,
      title: title,
      message: message,
      confirmLabel: label,
      destructive: destructive,
    )) {
      return;
    }
    await _run(
      decision,
      () async => (await _service.decide(
        app,
        decision: decision,
        comment: _comment.text.trim(),
      )).app,
      done: switch (decision) {
        'accept' => 'Application accepted',
        'reject' => 'Application rejected',
        _ => 'Re-opened',
      },
    );
    _comment.clear();
  }

  Future<void> _menu(String action) async {
    final app = _app!;
    switch (action) {
      case 'share':
        await showShareLinkSheet(
          context,
          name: app.fullName,
          email: app.email,
          link: app.link,
        );
      case 'remind':
        setState(() => _busy = 'remind');
        try {
          final sent = await _service.sendEmailNow(app.id);
          if (mounted) {
            _toast(
              sent
                  ? 'Email sent to ${app.email}'
                  : 'The email could not be sent.',
              error: !sent,
            );
          }
          await _load();
        } catch (e) {
          if (mounted) _toast(ApplicationService.errorText(e), error: true);
        } finally {
          if (mounted) setState(() => _busy = null);
        }
      case 'reminders':
        await _run(
          'reminders',
          () => _service.update(app, remindersOff: !app.remindersOff),
          done: app.remindersOff
              ? 'Automatic reminders on'
              : 'Automatic reminders off',
        );
      case 'edit':
        final edited = await _editApplicant(app);
        if (edited == null) return;
        await _run(
          'edit',
          () =>
              _service.update(app, fullName: edited.name, email: edited.email),
          done: 'Saved',
        );
      case 'newlink':
        if (!await webConfirm(
          context,
          title: 'Create a new link?',
          message:
              'The current link will stop working. Use this if the link was sent to the wrong person.',
          confirmLabel: 'Create new link',
        )) {
          return;
        }
        setState(() => _busy = 'newlink');
        try {
          final r = await _service.regenerateLink(app.id, sendEmail: false);
          await _load();
          if (mounted) {
            await showShareLinkSheet(
              context,
              name: app.fullName,
              email: app.email,
              link: r.link,
            );
          }
        } catch (e) {
          if (mounted) _toast(ApplicationService.errorText(e), error: true);
        } finally {
          if (mounted) setState(() => _busy = null);
        }
      case 'vault':
        await showVaultSettings(context);
      case 'delete':
        if (!await webConfirm(
          context,
          title: 'Delete ${app.fullName}\'s application?',
          message:
              'Their details and every uploaded document will be permanently deleted.',
          confirmLabel: 'Delete',
          destructive: true,
        )) {
          return;
        }
        setState(() => _busy = 'delete');
        try {
          await _service.delete(app.id);
          if (mounted) {
            _toast('Application deleted');
            Navigator.pop(context);
          }
        } catch (e) {
          if (mounted) {
            _toast(ApplicationService.errorText(e), error: true);
            setState(() => _busy = null);
          }
        }
    }
  }

  Future<({String name, String email})?> _editApplicant(
    ApplicationRecord app,
  ) => showDialog<({String name, String email})>(
    context: context,
    builder: (_) => _EditApplicantDialog(name: app.fullName, email: app.email),
  );

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    final app = _app;
    return Scaffold(
      appBar: AppBar(
        title: Text(app?.fullName ?? widget.name),
        actions: [
          if (app != null)
            PopupMenuButton<String>(
              onSelected: _menu,
              itemBuilder: (_) => [
                if (app.link.isNotEmpty && app.applicantHasWork)
                  const PopupMenuItem(
                    value: 'share',
                    child: Text('Share link'),
                  ),
                if (app.applicantHasWork && app.email.isNotEmpty)
                  const PopupMenuItem(
                    value: 'remind',
                    child: Text('Send reminder email now'),
                  ),
                if (app.applicantHasWork)
                  PopupMenuItem(
                    value: 'reminders',
                    child: Text(
                      app.remindersOff
                          ? 'Turn automatic reminders on'
                          : 'Turn automatic reminders off',
                    ),
                  ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit name / email'),
                ),
                const PopupMenuItem(
                  value: 'newlink',
                  child: Text('Create a new link'),
                ),
                const PopupMenuItem(
                  value: 'vault',
                  child: Text('Documents password'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete application',
                    style: TextStyle(color: AppTheme.errorColor),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : app == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _header(app),
                  const SizedBox(height: 12),
                  if (app.status == ApplicationStatus.accepted) ...[
                    OnboardingCard(
                      app: app,
                      onUpdated: (updated) => setState(() => _app = updated),
                      onReload: _load,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _decision(app),
                  const SizedBox(height: 12),
                  _documents(app),
                  const SizedBox(height: 12),
                  _details(app),
                  const SizedBox(height: 12),
                  _history(app),
                ],
              ),
            ),
    );
  }

  Widget _card({
    required String title,
    Widget? trailing,
    required List<Widget> children,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  Widget _header(ApplicationRecord app) {
    final (label, color) = applicationStatusDisplay(
      app.status,
      onboardingStatus: app.onboarding.status,
      lettersSigned: app.onboarding.signedCount,
      loginCreated: app.onboarding.loginCreated,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusChip(label: label, color: color),
            const SizedBox(height: 8),
            if (app.email.isNotEmpty)
              Text(app.email, style: const TextStyle(fontSize: 14)),
            if (app.details.phone.isNotEmpty)
              Text(app.details.phone, style: const TextStyle(fontSize: 14)),
            if (app.createdAt != null)
              Text(
                'Created ${DateFormat('MMM d, y').format(app.createdAt!)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            if (app.link.isNotEmpty && app.applicantHasWork) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => showShareLinkSheet(
                  context,
                  name: app.fullName,
                  email: app.email,
                  link: app.link,
                ),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share link'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _documents(ApplicationRecord app) {
    final approved = app.requiredDocuments
        .where((d) => app.doc(d.id).status == DocStatus.approved)
        .length;
    return _card(
      title: 'Documents',
      trailing: Text(
        '$approved of ${app.requiredDocuments.length} approved',
        style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
      ),
      children: [
        for (final d in app.requiredDocuments)
          Builder(
            builder: (context) {
              final doc = app.doc(d.id);
              final (Color color, String label) = switch (doc.status) {
                DocStatus.approved => (AppTheme.successColor, 'Approved'),
                DocStatus.uploaded => (AppTheme.primaryColor, 'To review'),
                DocStatus.needsChanges => (
                  AppTheme.warningColor,
                  'Needs changes',
                ),
                _ => (AppTheme.textSecondary, 'Not uploaded'),
              };
              final busy = _busy == 'doc-${d.id}' || _busy == 'view-${d.id}';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE3E8EF)),
                ),
                child: ListTile(
                  onTap: _busy != null ? null : () => _documentActions(d),
                  title: Text(
                    d.label,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      StatusChip(label: label, color: color),
                      if (doc.status == DocStatus.needsChanges &&
                          doc.comment.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Your comment: ${doc.comment}',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                    ],
                  ),
                  trailing: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.more_vert),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _decision(ApplicationRecord app) {
    final closed =
        app.status == ApplicationStatus.accepted ||
        app.status == ApplicationStatus.rejected;
    final waiting = ApplicationStatus.open.contains(app.status);
    return _card(
      title: 'Decision',
      children: [
        if (closed) ...[
          Text(
            app.status == ApplicationStatus.accepted
                ? 'Accepted.'
                : 'Rejected. The applicant\'s link is closed.',
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _busy != null ? null : () => _decide('reopen'),
            child: const Text('Re-open for review'),
          ),
        ] else ...[
          if (waiting)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                app.status == ApplicationStatus.needsChanges
                    ? 'Waiting for the applicant to fix the items you flagged.'
                    : 'Waiting for the applicant to submit.',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          TextField(
            controller: _comment,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Comment to the applicant (optional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy != null ? null : _requestChanges,
            icon: const Icon(Icons.reply, size: 18),
            label: const Text('Send back for changes'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                  ),
                  onPressed: _busy != null ? null : () => _decide('reject'),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                  ),
                  onPressed: _busy != null || !app.allApproved
                      ? null
                      : () => _decide('accept'),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
          if (!app.allApproved)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Approve every document to accept.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
            ),
        ],
        if (app.applicantHasWork) ...[
          const SizedBox(height: 10),
          Text(
            app.email.isEmpty
                ? 'No email on file, so there are no automatic reminders.'
                : app.remindersOff
                ? 'Automatic reminders are off.'
                : 'Reminder emails every 4 hours (8 am – 10 pm)${app.reminderCount > 0 ? ' · ${app.reminderCount} sent' : ''}.',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _details(ApplicationRecord app) {
    final d = app.details;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    List<Widget> contact(String title, Contact c) => [
      const SizedBox(height: 10),
      Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryColor,
        ),
      ),
      row('Name', c.name),
      row('Relation', c.relation),
      row('Phone', c.phone),
      row('Email', c.email),
    ];
    return _card(
      title: 'Details',
      children: [
        row('Full name', d.fullName),
        row('Email', d.email),
        row('Phone', d.phone),
        ...contact('Emergency contact', d.emergency),
        ...contact('Reference 1', d.references[0]),
        ...contact('Reference 2', d.references[1]),
      ],
    );
  }

  Widget _history(ApplicationRecord app) => _card(
    title: 'History',
    children: [
      if (app.activity.isEmpty)
        const Text(
          'Nothing yet.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      for (final a in app.activity.reversed)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a.text.isEmpty ? a.label : '${a.label}: ${a.text}',
                style: const TextStyle(fontSize: 13.5),
              ),
              Text(
                '${a.by}${a.at != null ? ' · ${DateFormat('MMM d, h:mm a').format(a.at!)}' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class _ImageViewer extends StatelessWidget {
  final String title;
  final Uint8List bytes;
  const _ImageViewer({required this.title, required this.bytes});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: Text(title),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    ),
    body: InteractiveViewer(
      maxScale: 6,
      child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
    ),
  );
}

class _EditApplicantDialog extends StatefulWidget {
  final String name;
  final String email;
  const _EditApplicantDialog({required this.name, required this.email});

  @override
  State<_EditApplicantDialog> createState() => _EditApplicantDialogState();
}

class _EditApplicantDialogState extends State<_EditApplicantDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.name);
  late final _email = TextEditingController(text: widget.email);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit applicant'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) {
                final t = v?.trim() ?? '';
                return t.isEmpty ||
                        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t)
                    ? null
                    : 'Enter a valid email';
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, (
                name: _name.text.trim(),
                email: _email.text.trim(),
              ));
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
