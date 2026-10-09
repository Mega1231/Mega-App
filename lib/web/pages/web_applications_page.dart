import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/caregiver_application.dart';
import '../../services/application_service.dart';
import '../../services/download/file_download.dart';
import '../../theme/app_theme.dart';
import '../admin_web_shell.dart';
import '../web_widgets.dart';
import '../../widgets/comment_dialog.dart';
import 'web_documents_vault.dart';
import 'web_onboarding_card.dart';

/// Caregiver applications (onboarding stage 1): send a link, follow
/// progress, review each document, request changes, accept or reject.
class WebApplicationsPage extends StatefulWidget {
  const WebApplicationsPage({super.key});

  @override
  State<WebApplicationsPage> createState() => _WebApplicationsPageState();
}

class _WebApplicationsPageState extends State<WebApplicationsPage> {
  final _service = ApplicationService();
  List<ApplicationSummary>? _apps;
  String? _error;
  int _filter = 0;
  String _query = '';
  String? _openId;

  static const _filters = [
    'All',
    'To review',
    'Waiting on applicant',
    'Accepted',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final apps = await _service.list();
      if (mounted) {
        setState(() {
          _apps = apps;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = ApplicationService.errorText(e));
    }
  }

  bool _matchesFilter(ApplicationSummary a, int f) => switch (f) {
    1 => a.status == ApplicationStatus.submitted,
    2 => a.applicantHasWork,
    3 => a.status == ApplicationStatus.accepted,
    4 => a.status == ApplicationStatus.rejected,
    _ => true,
  };

  Future<void> _create() async {
    final created = await showDialog<_Created>(
      context: context,
      builder: (_) => const _NewApplicationDialog(),
    );
    if (created == null || !mounted) return;
    await _load();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _LinkDialog(
        name: created.name,
        email: created.email,
        link: created.link,
        emailSent: created.emailSent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_openId != null) {
      return _ApplicationDetail(
        id: _openId!,
        onBack: () {
          setState(() => _openId = null);
          _load();
        },
      );
    }
    final apps = _apps;
    final visible = (apps ?? const <ApplicationSummary>[])
        .where((a) => _matchesFilter(a, _filter))
        .where((a) {
          final q = _query.toLowerCase();
          return q.isEmpty ||
              a.fullName.toLowerCase().contains(q) ||
              a.email.toLowerCase().contains(q) ||
              a.phone.contains(q);
        })
        .toList();

    return WebPageScaffold(
      onRefresh: _load,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WebPageHeader(
            title: 'Applications',
            subtitle:
                'Send a link to new caregivers, then review their details and documents',
            actions: [
              OutlinedButton.icon(
                onPressed: () => showVaultSettings(context),
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Documents password'),
              ),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New application'),
              ),
            ],
          ),
          WebToolbar(
            leading: [
              WebFilterTabs(
                labels: [
                  for (int i = 0; i < _filters.length; i++)
                    '${_filters[i]} (${(apps ?? const []).where((a) => _matchesFilter(a, i)).length})',
                ],
                selected: _filter,
                onChanged: (i) => setState(() => _filter = i),
              ),
            ],
            trailing: WebSearchField(
              hint: 'Search name, email or phone',
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            WebCard(
              child: WebEmptyState(icon: Icons.error_outline, message: _error!),
            )
          else if (apps == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            WebTable(
              headers: const [
                'Applicant',
                'Status',
                'Documents',
                'Last activity',
                '',
              ],
              flex: const [5, 3, 3, 3, 2],
              onRowTap: (i) => setState(() => _openId = visible[i].id),
              empty: WebEmptyState(
                icon: Icons.assignment_ind_outlined,
                message: apps.isEmpty
                    ? 'No applications yet. Press "New application" to send a link to a caregiver.'
                    : 'No applications match.',
              ),
              rows: [
                for (final a in visible)
                  [
                    _NameCell(
                      name: a.fullName,
                      sub: a.email.isEmpty ? a.phone : a.email,
                    ),
                    _StatusBadge(status: a.status, summary: a),
                    _DocsProgress(app: a),
                    Text(
                      _ago(a.lastApplicantActivityAt ?? a.createdAt),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (a.link.isNotEmpty && a.applicantHasWork)
                          _ShareButton(
                            name: a.fullName,
                            link: a.link,
                            email: a.email,
                          ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ],
              ],
            ),
        ],
      ),
    );
  }
}

// ── Detail / review ──

class _ApplicationDetail extends StatefulWidget {
  final String id;
  final VoidCallback onBack;

  const _ApplicationDetail({required this.id, required this.onBack});

  @override
  State<_ApplicationDetail> createState() => _ApplicationDetailState();
}

class _ApplicationDetailState extends State<_ApplicationDetail> {
  final _service = ApplicationService();
  final _comment = TextEditingController();
  ApplicationRecord? _app;
  String? _error;
  String? _busy; // which action is running

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

  /// Runs an action that returns the updated record, with a busy state.
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
      if (done != null) webToast(context, done);
    } catch (e) {
      if (mounted) {
        webToast(context, ApplicationService.errorText(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

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
      final displayable = {
        'image/jpeg',
        'image/png',
        'image/webp',
      }.contains(file.contentType);
      if (displayable) {
        await showDialog(
          context: context,
          builder: (_) => _ImageViewer(
            title: '${d.label} · ${file.fileName}',
            bytes: file.bytes,
            onDownload: () => saveGeneratedFile(
              file.bytes,
              file.fileName,
              mimeType: file.contentType,
            ),
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
      if (mounted) {
        webToast(context, ApplicationService.errorText(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _flag(RequiredDocument d) async {
    final comment = await _askComment(
      context,
      title: 'What needs to change? — ${d.label}',
      hint: 'e.g. The photo is blurry, please take it again in good light',
      confirm: 'Mark as needs changes',
      initial: _app!.doc(d.id).comment,
    );
    if (comment == null) return;
    await _run(
      'doc-${d.id}',
      () => _service.reviewDocument(
        _app!,
        docType: d.id,
        decision: DocStatus.needsChanges,
        comment: comment,
      ),
    );
  }

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
            : 'They have no email, so send them the link yourself (Copy / WhatsApp).',
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
      webToast(
        context,
        r.emailSent
            ? 'Sent back — ${app.email} was emailed'
            : 'Sent back. The email could not be sent, so please share the link yourself.',
        error: !r.emailSent && app.email.isNotEmpty,
      );
    } catch (e) {
      if (mounted) {
        webToast(context, ApplicationService.errorText(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _decide(String decision) async {
    final app = _app!;
    final (title, message, label, destructive) = switch (decision) {
      'accept' => (
        'Accept ${app.fullName}?',
        'Their application will be marked accepted. Next come the onboarding documents.',
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
    final ok = await webConfirm(
      context,
      title: title,
      message: message,
      confirmLabel: label,
      destructive: destructive,
    );
    if (!ok) return;
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
      case 'remind':
        setState(() => _busy = 'remind');
        try {
          final sent = await _service.sendEmailNow(app.id);
          if (mounted) {
            webToast(
              context,
              sent
                  ? 'Email sent to ${app.email}'
                  : 'The email could not be sent.',
              error: !sent,
            );
          }
          await _load();
        } catch (e) {
          if (mounted) {
            webToast(context, ApplicationService.errorText(e), error: true);
          }
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
        final edited = await showDialog<({String name, String email})>(
          context: context,
          builder: (_) =>
              _EditApplicantDialog(name: app.fullName, email: app.email),
        );
        if (edited == null) return;
        await _run(
          'edit',
          () =>
              _service.update(app, fullName: edited.name, email: edited.email),
          done: 'Saved',
        );
      case 'newlink':
        final ok = await webConfirm(
          context,
          title: 'Create a new link?',
          message:
              'The current link will stop working. Use this if the link was sent to the wrong person.',
          confirmLabel: 'Create new link',
        );
        if (!ok) return;
        setState(() => _busy = 'newlink');
        try {
          final r = await _service.regenerateLink(app.id, sendEmail: false);
          await _load();
          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (_) => _LinkDialog(
              name: app.fullName,
              email: app.email,
              link: r.link,
              emailSent: false,
            ),
          );
        } catch (e) {
          if (mounted) {
            webToast(context, ApplicationService.errorText(e), error: true);
          }
        } finally {
          if (mounted) setState(() => _busy = null);
        }
      case 'delete':
        final ok = await webConfirm(
          context,
          title: 'Delete ${app.fullName}\'s application?',
          message:
              'Their details and every uploaded document will be permanently deleted.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!ok) return;
        setState(() => _busy = 'delete');
        try {
          await _service.delete(app.id);
          if (mounted) {
            webToast(context, 'Application deleted');
            widget.onBack();
          }
        } catch (e) {
          if (mounted) {
            webToast(context, ApplicationService.errorText(e), error: true);
            setState(() => _busy = null);
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    return WebPageScaffold(
      onRefresh: _load,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('All applications'),
            ),
          ),
          const SizedBox(height: 8),
          if (_error != null)
            WebCard(
              child: WebEmptyState(icon: Icons.error_outline, message: _error!),
            )
          else if (app == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            WebPageHeader(
              title: app.fullName,
              subtitle: [
                ApplicationStatus.label(app.status),
                if (app.email.isNotEmpty) app.email,
                if (app.createdAt != null)
                  'created ${DateFormat('MMM d, y').format(app.createdAt!)}',
              ].join(' · '),
              actions: [
                if (app.link.isNotEmpty && app.applicantHasWork)
                  _ShareButton(
                    name: app.fullName,
                    link: app.link,
                    email: app.email,
                    labeled: true,
                  ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: _menu,
                  itemBuilder: (_) => [
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
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete application',
                        style: TextStyle(color: AppTheme.errorColor),
                      ),
                    ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.more_vert),
                  ),
                ),
              ],
            ),
            LayoutBuilder(
              builder: (context, c) {
                final documents = app.status == ApplicationStatus.accepted
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OnboardingCard(
                            app: app,
                            onUpdated: (updated) =>
                                setState(() => _app = updated),
                            onReload: _load,
                          ),
                          const SizedBox(height: 16),
                          _documentsCard(app),
                        ],
                      )
                    : _documentsCard(app);
                final side = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _decisionCard(app),
                    const SizedBox(height: 16),
                    _detailsCard(app),
                    const SizedBox(height: 16),
                    _activityCard(app),
                  ],
                );
                if (c.maxWidth < 980) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [documents, const SizedBox(height: 16), side],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: documents),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: side),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        ?trailing,
      ],
    ),
  );

  Widget _documentsCard(ApplicationRecord app) {
    final approved = app.requiredDocuments
        .where((d) => app.doc(d.id).status == DocStatus.approved)
        .length;
    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(
            'Documents',
            trailing: Text(
              '$approved of ${app.requiredDocuments.length} approved',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          for (final d in app.requiredDocuments) _documentRow(app, d),
        ],
      ),
    );
  }

  Widget _documentRow(ApplicationRecord app, RequiredDocument d) {
    final doc = app.doc(d.id);
    final busy = _busy == 'doc-${d.id}' || _busy == 'view-${d.id}';
    final reviewable =
        doc.hasFile &&
        app.status != ApplicationStatus.accepted &&
        app.status != ApplicationStatus.rejected;
    final (Color color, String label) = switch (doc.status) {
      DocStatus.approved => (AppTheme.successColor, 'Approved'),
      DocStatus.uploaded => (AppTheme.primaryColor, 'Uploaded — to review'),
      DocStatus.needsChanges => (AppTheme.warningColor, 'Needs changes'),
      _ => (AppTheme.textSecondary, 'Not uploaded'),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: WebTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.label,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        WebStatusBadge(label: label, color: color),
                        if (doc.hasFile)
                          Text(
                            '${doc.fileName}${doc.uploadedAt != null ? ' · ${DateFormat('MMM d, h:mm a').format(doc.uploadedAt!)}' : ''}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else ...[
                if (doc.hasFile)
                  TextButton.icon(
                    onPressed: _busy != null ? null : () => _view(d),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('View'),
                  ),
                if (reviewable && doc.status != DocStatus.approved)
                  IconButton(
                    tooltip: 'Approve',
                    onPressed: _busy != null
                        ? null
                        : () => _run(
                            'doc-${d.id}',
                            () => _service.reviewDocument(
                              app,
                              docType: d.id,
                              decision: DocStatus.approved,
                            ),
                          ),
                    icon: const Icon(
                      Icons.check_circle_outline,
                      color: AppTheme.successColor,
                    ),
                  ),
                if (reviewable)
                  IconButton(
                    tooltip: 'Needs changes',
                    onPressed: _busy != null ? null : () => _flag(d),
                    icon: const Icon(
                      Icons.edit_note,
                      color: AppTheme.warningColor,
                    ),
                  ),
                if (reviewable && doc.status != DocStatus.uploaded)
                  IconButton(
                    tooltip: 'Undo review',
                    onPressed: _busy != null
                        ? null
                        : () => _run(
                            'doc-${d.id}',
                            () => _service.reviewDocument(
                              app,
                              docType: d.id,
                              decision: DocStatus.uploaded,
                            ),
                          ),
                    icon: const Icon(
                      Icons.undo,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ],
          ),
          if (doc.status == DocStatus.needsChanges && doc.comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Your comment: ${doc.comment}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (doc.history.isNotEmpty)
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  'Earlier uploads (${doc.history.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                children: [
                  for (final h in doc.history.reversed)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history, size: 18),
                      title: Text(
                        h.fileName,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        [
                          if (h.uploadedAt != null)
                            'Uploaded ${DateFormat('MMM d, h:mm a').format(h.uploadedAt!)}',
                          if (h.status == DocStatus.needsChanges)
                            'Needed changes',
                          if (h.comment.isNotEmpty) '"${h.comment}"',
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: TextButton(
                        onPressed: _busy != null
                            ? null
                            : () => _view(d, version: h),
                        child: const Text('View'),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _decisionCard(ApplicationRecord app) {
    final closed =
        app.status == ApplicationStatus.accepted ||
        app.status == ApplicationStatus.rejected;
    final waiting = ApplicationStatus.open.contains(app.status);
    Widget spinner() => const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Decision'),
          if (closed) ...[
            Text(
              app.status == ApplicationStatus.accepted
                  ? 'Accepted. Onboarding documents are the next step.'
                  : 'Rejected. The applicant\'s link is closed.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy != null ? null : () => _decide('reopen'),
              child: const Text('Re-open for review'),
            ),
          ] else ...[
            if (waiting)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  app.status == ApplicationStatus.needsChanges
                      ? 'Waiting for the applicant to fix the items you flagged.'
                      : 'Waiting for the applicant to submit.${app.problems.isEmpty ? '' : ' Still missing: ${app.problems.length} item${app.problems.length == 1 ? '' : 's'}.'}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            TextField(
              controller: _comment,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Comment to the applicant (optional)',
                hintText: 'Shown on their page and in the email',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy != null ? null : _requestChanges,
              icon: _busy == 'request'
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.reply, size: 18),
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
                  child: Tooltip(
                    message: app.allApproved
                        ? ''
                        : 'Approve every document first',
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                      ),
                      onPressed: _busy != null || !app.allApproved
                          ? null
                          : () => _decide('accept'),
                      child: _busy == 'accept'
                          ? spinner()
                          : const Text('Accept'),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (app.generalComment.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Last comment sent: "${app.generalComment}"',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          if (waiting) ...[
            const SizedBox(height: 14),
            Text(
              app.email.isEmpty
                  ? 'No email on file, so there are no automatic reminders.'
                  : app.remindersOff
                  ? 'Automatic reminders are off.'
                  : 'Reminder emails every 4 hours (8 am – 10 pm)${app.reminderCount > 0 ? ' · ${app.reminderCount} sent' : ''}${app.lastReminderAt != null ? ', last ${_ago(app.lastReminderAt)}' : ''}.',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailsCard(ApplicationRecord app) {
    final d = app.details;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
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
    Widget contact(String title, Contact c) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 2),
        row('Name', c.name),
        row('Relation', c.relation),
        row('Phone', c.phone),
        row('Email', c.email),
      ],
    );
    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Details'),
          row('Full name', d.fullName),
          row('Email', d.email),
          row('Phone', d.phone),
          contact('Emergency contact', d.emergency),
          contact('Reference 1', d.references[0]),
          contact('Reference 2', d.references[1]),
        ],
      ),
    );
  }

  Widget _activityCard(ApplicationRecord app) => WebCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('History'),
        if (app.activity.isEmpty)
          const Text(
            'Nothing yet.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        for (final a in app.activity.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Icon(
                    Icons.circle,
                    size: 8,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
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
            ),
          ),
      ],
    ),
  );
}

// ── Small pieces ──

String _ago(DateTime? t) {
  if (t == null) return '—';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 7) return '${d.inDays} d ago';
  return DateFormat('MMM d').format(t);
}

/// Asks for a comment; null when cancelled.
Future<String?> _askComment(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirm,
  String initial = '',
}) => showCommentDialog(
  context,
  title: title,
  confirmLabel: confirm,
  hint: hint,
  helper: 'The applicant sees this on their page and in the email.',
  initial: initial,
);

String _shareText(String name, String link) {
  final first = name.trim().split(RegExp(r'\s+')).first;
  return 'Hi $first, please complete your Mega Homecare caregiver application here: $link\n'
      'Fill in your details and upload your documents (photos from your phone are fine). Thank you!';
}

Future<void> _copyLink(BuildContext context, String link) async {
  await Clipboard.setData(ClipboardData(text: link));
  if (context.mounted) webToast(context, 'Link copied');
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final ApplicationSummary? summary;
  const _StatusBadge({required this.status, this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    if (status == ApplicationStatus.accepted && s != null) {
      // Accepted rows show where onboarding stands.
      final (label, color) = s.loginCreated
          ? ('Login created', AppTheme.successColor)
          : switch (s.onboardingStatus) {
              OnboardingStatus.completed => (
                'Documents signed',
                AppTheme.successColor,
              ),
              OnboardingStatus.sent => (
                'Signing ${s.lettersSigned}/5',
                AppTheme.primaryColor,
              ),
              _ => ('Accepted · send documents', AppTheme.warningColor),
            };
      return WebStatusBadge(label: label, color: color);
    }
    final color = switch (status) {
      ApplicationStatus.submitted => AppTheme.primaryColor,
      ApplicationStatus.needsChanges => AppTheme.warningColor,
      ApplicationStatus.accepted => AppTheme.successColor,
      ApplicationStatus.rejected => AppTheme.errorColor,
      _ => AppTheme.textSecondary,
    };
    return WebStatusBadge(label: ApplicationStatus.label(status), color: color);
  }
}

class _NameCell extends StatelessWidget {
  final String name;
  final String sub;
  const _NameCell({required this.name, required this.sub});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      WebAvatar(name: name, size: 36),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _DocsProgress extends StatelessWidget {
  final ApplicationSummary app;
  const _DocsProgress({required this.app});

  @override
  Widget build(BuildContext context) {
    final total = app.total == 0 ? 1 : app.total;
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${app.uploaded}/${app.total} uploaded'
            '${app.approved > 0 ? ' · ${app.approved} ok' : ''}'
            '${app.needsChanges > 0 ? ' · ${app.needsChanges} to fix' : ''}',
            style: const TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: app.uploaded / total,
              minHeight: 5,
              backgroundColor: WebTokens.border,
              color: app.uploaded == app.total
                  ? AppTheme.successColor
                  : AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Copy link + share via WhatsApp / SMS / email.
class _ShareButton extends StatelessWidget {
  final String name;
  final String link;
  final String email;
  final bool labeled;

  const _ShareButton({
    required this.name,
    required this.link,
    required this.email,
    this.labeled = false,
  });

  Future<void> _share(BuildContext context, String via) async {
    final text = _shareText(name, link);
    final uri = switch (via) {
      'whatsapp' => Uri.parse(
        'https://wa.me/?text=${Uri.encodeComponent(text)}',
      ),
      'sms' => Uri.parse('sms:?&body=${Uri.encodeComponent(text)}'),
      _ => Uri(
        scheme: 'mailto',
        path: email,
        query:
            'subject=${Uri.encodeComponent('Mega Homecare – your application')}'
            '&body=${Uri.encodeComponent(text)}',
      ),
    };
    if (!await launchUrl(uri, webOnlyWindowName: '_blank') && context.mounted) {
      webToast(
        context,
        'Could not open that app. The link was copied instead.',
      );
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        labeled
            ? OutlinedButton.icon(
                onPressed: () => _copyLink(context, link),
                icon: const Icon(Icons.link, size: 18),
                label: const Text('Copy link'),
              )
            : IconButton(
                tooltip: 'Copy link',
                onPressed: () => _copyLink(context, link),
                icon: const Icon(Icons.link, size: 20),
              ),
        PopupMenuButton<String>(
          tooltip: 'Share link',
          onSelected: (v) => v == 'message'
              ? Clipboard.setData(
                  ClipboardData(text: _shareText(name, link)),
                ).then(
                  (_) => context.mounted
                      ? webToast(context, 'Message copied')
                      : null,
                )
              : _share(context, v),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'whatsapp',
              child: Text('Share on WhatsApp'),
            ),
            const PopupMenuItem(
              value: 'sms',
              child: Text('Send as text message'),
            ),
            if (email.isNotEmpty)
              const PopupMenuItem(
                value: 'email',
                child: Text('Open in my email'),
              ),
            const PopupMenuItem(
              value: 'message',
              child: Text('Copy full message'),
            ),
          ],
          child: labeled
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Chip(
                    avatar: Icon(Icons.share_outlined, size: 18),
                    label: Text('Share'),
                  ),
                )
              : const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.share_outlined, size: 20),
                ),
        ),
      ],
    );
  }
}

class _Created {
  final String name;
  final String email;
  final String link;
  final bool emailSent;
  const _Created(this.name, this.email, this.link, this.emailSent);
}

class _NewApplicationDialog extends StatefulWidget {
  const _NewApplicationDialog();

  @override
  State<_NewApplicationDialog> createState() => _NewApplicationDialogState();
}

class _NewApplicationDialogState extends State<_NewApplicationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _sendEmail = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      final r = await ApplicationService().create(
        fullName: _name.text.trim(),
        email: email,
        sendEmail: _sendEmail && email.isNotEmpty,
      );
      if (mounted) {
        Navigator.pop(
          context,
          _Created(_name.text.trim(), email, r.link, r.emailSent),
        );
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
      title: const Text('New application'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You will get a link to send to the caregiver. They fill in their details and upload documents from their phone — no login needed.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Caregiver full name',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  helperText:
                      'Needed for reminder emails. They can also add it themselves.',
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  return t.isEmpty ||
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t)
                      ? null
                      : 'Enter a valid email';
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _sendEmail && _email.text.trim().isNotEmpty,
                onChanged: _email.text.trim().isEmpty
                    ? null
                    : (v) => setState(() => _sendEmail = v == true),
                title: const Text(
                  'Also email them the link',
                  style: TextStyle(fontSize: 14),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppTheme.errorColor,
                    fontSize: 13,
                  ),
                ),
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
              : const Text('Create link'),
        ),
      ],
    );
  }
}

class _LinkDialog extends StatelessWidget {
  final String name;
  final String email;
  final String link;
  final bool emailSent;

  const _LinkDialog({
    required this.name,
    required this.email,
    required this.link,
    required this.emailSent,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text('Link for $name'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: WebTokens.pageBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: WebTokens.border),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              emailSent
                  ? 'The link was also emailed to $email.'
                  : email.isNotEmpty
                  ? 'The email was not sent. Share the link with WhatsApp or a text message.'
                  : 'Share the link with WhatsApp or a text message.',
              style: const TextStyle(
                fontSize: 13.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
      actions: [
        _ShareButton(name: name, link: link, email: email, labeled: true),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Edit applicant'),
      content: SizedBox(
        width: 420,
        child: Form(
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, (
              name: _name.text.trim(),
              email: _email.text.trim(),
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ImageViewer extends StatelessWidget {
  final String title;
  final Uint8List bytes;
  final VoidCallback onDownload;

  const _ImageViewer({
    required this.title,
    required this.bytes,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size.width * 0.8,
        height: size.height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Download'),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: WebTokens.border),
            Expanded(
              child: Container(
                color: const Color(0xFF1B2330),
                child: InteractiveViewer(
                  maxScale: 6,
                  child: Center(
                    child: Image.memory(bytes, fit: BoxFit.contain),
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
