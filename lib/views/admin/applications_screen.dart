import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/caregiver_application.dart';
import '../../services/application_service.dart';
import '../../theme/app_theme.dart';
import '../../web/pages/web_documents_vault.dart';
import 'application_detail_screen.dart';

/// Caregiver applications on the mobile admin app: the same flow as the web
/// panel's Applications section, laid out for a phone.
class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  final _service = ApplicationService();
  List<ApplicationSummary>? _apps;
  String? _error;
  int _filter = 0;
  String _query = '';

  static const _filters = [
    'All',
    'To review',
    'Waiting',
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

  bool _matches(ApplicationSummary a, int f) => switch (f) {
    1 => a.status == ApplicationStatus.submitted,
    2 => a.applicantHasWork,
    3 => a.status == ApplicationStatus.accepted,
    4 => a.status == ApplicationStatus.rejected,
    _ => true,
  };

  Future<void> _create() async {
    final created =
        await showModalBottomSheet<
          ({String name, String email, String link, bool emailSent})
        >(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => const _NewApplicationSheet(),
        );
    if (created == null || !mounted) return;
    _load();
    await showShareLinkSheet(
      context,
      name: created.name,
      email: created.email,
      link: created.link,
      note: created.emailSent
          ? 'The link was also emailed to ${created.email}.'
          : created.email.isNotEmpty
          ? 'The email could not be sent. Share the link below.'
          : 'Share the link below.',
    );
  }

  Future<void> _open(ApplicationSummary a) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApplicationDetailScreen(id: a.id, name: a.fullName),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final apps = _apps ?? const <ApplicationSummary>[];
    final q = _query.toLowerCase();
    final visible = apps
        .where((a) => _matches(a, _filter))
        .where(
          (a) =>
              q.isEmpty ||
              a.fullName.toLowerCase().contains(q) ||
              a.email.toLowerCase().contains(q) ||
              a.phone.contains(q),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caregiver Applications'),
        actions: [
          IconButton(
            tooltip: 'Documents password',
            icon: const Icon(Icons.lock_outline),
            onPressed: () => showVaultSettings(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('New application'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: const InputDecoration(
                hintText: 'Search name, email or phone',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < _filters.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          '${_filters[i]} (${apps.where((a) => _matches(a, i)).length})',
                        ),
                        selected: _filter == i,
                        onSelected: (_) => setState(() => _filter = i),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              _Empty(icon: Icons.error_outline, text: _error!)
            else if (_apps == null)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (visible.isEmpty)
              _Empty(
                icon: Icons.assignment_ind_outlined,
                text: apps.isEmpty
                    ? 'No applications yet. Tap "New application" to send a link to a caregiver.'
                    : 'No applications match.',
              )
            else
              for (final a in visible)
                _ApplicationTile(app: a, onTap: () => _open(a)),
          ],
        ),
      ),
    );
  }
}

/// Label and colour for an application's status, including where
/// onboarding stands once accepted.
(String, Color) applicationStatusDisplay(
  String status, {
  String onboardingStatus = OnboardingStatus.notSent,
  int lettersSigned = 0,
  bool loginCreated = false,
}) {
  if (status == ApplicationStatus.accepted) {
    if (loginCreated) return ('Login created', AppTheme.successColor);
    return switch (onboardingStatus) {
      OnboardingStatus.completed => ('Documents signed', AppTheme.successColor),
      OnboardingStatus.sent => (
        'Signing $lettersSigned/5',
        AppTheme.primaryColor,
      ),
      _ => ('Accepted · send documents', AppTheme.warningColor),
    };
  }
  final color = switch (status) {
    ApplicationStatus.submitted => AppTheme.primaryColor,
    ApplicationStatus.needsChanges => AppTheme.warningColor,
    ApplicationStatus.rejected => AppTheme.errorColor,
    _ => AppTheme.textSecondary,
  };
  return (ApplicationStatus.label(status), color);
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class _ApplicationTile extends StatelessWidget {
  final ApplicationSummary app;
  final VoidCallback onTap;
  const _ApplicationTile({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (label, color) = applicationStatusDisplay(
      app.status,
      onboardingStatus: app.onboardingStatus,
      lettersSigned: app.lettersSigned,
      loginCreated: app.loginCreated,
    );
    final total = app.total == 0 ? 1 : app.total;
    final last = app.lastApplicantActivityAt ?? app.createdAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.1,
                    ),
                    child: Text(
                      app.fullName.isEmpty
                          ? '?'
                          : app.fullName[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          app.email.isNotEmpty ? app.email : app.phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  StatusChip(label: label, color: color),
                  const Spacer(),
                  if (last != null)
                    Text(
                      DateFormat('MMM d').format(last),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: app.uploaded / total,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFE3E8EF),
                        color: app.uploaded == app.total
                            ? AppTheme.successColor
                            : AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${app.uploaded}/${app.total} documents',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
    child: Column(
      children: [
        Icon(
          icon,
          size: 44,
          color: AppTheme.textSecondary.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      ],
    ),
  );
}

class _NewApplicationSheet extends StatefulWidget {
  const _NewApplicationSheet();

  @override
  State<_NewApplicationSheet> createState() => _NewApplicationSheetState();
}

class _NewApplicationSheetState extends State<_NewApplicationSheet> {
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
    final email = _email.text.trim();
    try {
      final r = await ApplicationService().create(
        fullName: _name.text.trim(),
        email: email,
        sendEmail: _sendEmail && email.isNotEmpty,
      );
      if (mounted) {
        Navigator.pop(context, (
          name: _name.text.trim(),
          email: email,
          link: r.link,
          emailSent: r.emailSent,
        ));
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
    final hasEmail = _email.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'New application',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'You get a link to send to the caregiver. They fill in their details and upload documents from their phone — no login needed.',
              style: TextStyle(
                fontSize: 13.5,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
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
                labelText: 'Email (for reminders)',
                helperText: 'Optional — they can also add it themselves.',
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final t = v?.trim() ?? '';
                return t.isEmpty ||
                        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t)
                    ? null
                    : 'Enter a valid email';
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _sendEmail && hasEmail,
              onChanged: hasEmail
                  ? (v) => setState(() => _sendEmail = v == true)
                  : null,
              title: const Text('Also email them the link'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
              ),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create link'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _shareText(String name, String link) {
  final first = name.trim().split(RegExp(r'\s+')).first;
  return 'Hi $first, please complete your Mega Homecare caregiver application here: $link\n'
      'Fill in your details and upload your documents (photos from your phone are fine). Thank you!';
}

/// Copy / WhatsApp / text / email for an application link.
Future<void> showShareLinkSheet(
  BuildContext context, {
  required String name,
  required String email,
  required String link,
  String? note,
}) {
  Future<void> launch(BuildContext ctx, Uri uri) async {
    final messenger = ScaffoldMessenger.of(ctx);
    Navigator.pop(ctx);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await Clipboard.setData(ClipboardData(text: _shareText(name, link)));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not open that app. The message was copied.'),
        ),
      );
    }
  }

  final text = _shareText(name, link);
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Link for $name',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    note,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SelectableText(link, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.chat_outlined, color: Color(0xFF25D366)),
            title: const Text('Share on WhatsApp'),
            onTap: () => launch(
              ctx,
              Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sms_outlined),
            title: const Text('Send as text message'),
            onTap: () => launch(
              ctx,
              Uri.parse('sms:?&body=${Uri.encodeComponent(text)}'),
            ),
          ),
          if (email.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Open in my email'),
              onTap: () => launch(
                ctx,
                Uri(
                  scheme: 'mailto',
                  path: email,
                  query:
                      'subject=${Uri.encodeComponent('Mega Homecare – your application')}'
                      '&body=${Uri.encodeComponent(text)}',
                ),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Copy link'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(ctx);
              await Clipboard.setData(ClipboardData(text: link));
              if (ctx.mounted) Navigator.pop(ctx);
              messenger.showSnackBar(
                const SnackBar(content: Text('Link copied')),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
