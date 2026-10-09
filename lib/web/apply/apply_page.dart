import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/caregiver_application.dart';
import '../../services/application_service.dart';
import '../../theme/app_theme.dart';
import 'onboarding_section.dart';

/// Public page an applicant opens from the link Becky sends
/// (`mega-h.web.app/apply/<token>`). No login: the token identifies the
/// application. Built for phones first — most applicants open it from
/// WhatsApp or SMS.
class ApplyPage extends StatefulWidget {
  final String token;
  const ApplyPage({super.key, required this.token});

  @override
  State<ApplyPage> createState() => _ApplyPageState();
}

class _ApplyPageState extends State<ApplyPage> {
  final _service = ApplicationService();
  final _formKey = GlobalKey<FormState>();
  ApplicantApplication? _app;
  String? _loadError;
  bool _saving = false;
  bool _submitting = false;
  bool _detailsDirty = false;
  final Set<String> _uploading = {};

  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _emergency = _ContactControllers();
  final _references = [_ContactControllers(), _ContactControllers()];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_fullName, _email, _phone]) {
      c.dispose();
    }
    _emergency.dispose();
    for (final r in _references) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final app = await _service.load(widget.token);
      _fill(app.details, app);
      setState(() => _app = app);
    } catch (e) {
      setState(() => _loadError = ApplicationService.errorText(e));
    }
  }

  void _fill(ApplicantDetails d, ApplicantApplication app) {
    _fullName.text = d.fullName.isNotEmpty ? d.fullName : app.fullName;
    _email.text = d.email.isNotEmpty ? d.email : app.email;
    _phone.text = d.phone;
    _emergency.fill(d.emergency);
    for (int i = 0; i < 2; i++) {
      _references[i].fill(d.references[i]);
    }
    _detailsDirty = false;
  }

  ApplicantDetails _details() => ApplicantDetails(
    fullName: _fullName.text.trim(),
    email: _email.text.trim(),
    phone: _phone.text.trim(),
    emergency: _emergency.value,
    references: _references.map((r) => r.value).toList(),
  );

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? AppTheme.errorColor : AppTheme.textPrimary,
      ),
    );
  }

  Future<bool> _saveDetails({bool quiet = false}) async {
    setState(() => _saving = true);
    try {
      final app = await _service.saveDetails(widget.token, _details());
      setState(() {
        _app = app;
        _detailsDirty = false;
      });
      if (!quiet) _toast('Your details are saved');
      return true;
    } catch (e) {
      _toast(ApplicationService.errorText(e), error: true);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Uploads ──

  static const _maxBytes = 10 * 1024 * 1024;

  static String? _typeFor(String fileName, String? mime) {
    final ext = fileName.split('.').last.toLowerCase();
    final byExt = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => null,
    };
    if (mime != null && mime.isNotEmpty && mime != 'application/octet-stream') {
      return mime.toLowerCase();
    }
    return byExt;
  }

  Future<void> _pickAndUpload(RequiredDocument d) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose a photo'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Choose a PDF or file'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    String fileName;
    String? mime;
    Uint8List bytes;
    try {
      if (source == 'file') {
        final picked = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const [
            'pdf',
            'jpg',
            'jpeg',
            'png',
            'heic',
            'webp',
          ],
          withData: true,
        );
        final f = picked?.files.single;
        if (f?.bytes == null) return;
        fileName = f!.name;
        bytes = f.bytes!;
      } else {
        // Resized in the browser so phone photos upload quickly.
        final x = await ImagePicker().pickImage(
          source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 2200,
          maxHeight: 2200,
          imageQuality: 85,
        );
        if (x == null) return;
        fileName = x.name.contains('.') ? x.name : '${d.id}.jpg';
        mime = x.mimeType;
        bytes = await x.readAsBytes();
      }
    } catch (e) {
      _toast('Could not open that file. Please try again.', error: true);
      return;
    }

    final type = _typeFor(fileName, mime);
    if (type == null) {
      _toast('Please upload a photo (JPG, PNG) or a PDF.', error: true);
      return;
    }
    if (bytes.length > _maxBytes) {
      _toast(
        'That file is over 10 MB. Please take a photo instead, or send a smaller PDF.',
        error: true,
      );
      return;
    }

    setState(() => _uploading.add(d.id));
    try {
      final app = await _service.upload(
        widget.token,
        docType: d.id,
        fileName: fileName,
        contentType: type,
        bytes: bytes,
      );
      setState(() => _app = app);
      _toast('${d.label} uploaded');
    } catch (e) {
      _toast(ApplicationService.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _uploading.remove(d.id));
    }
  }

  // ── Submit ──

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _toast('Please fill in all your details first.', error: true);
      return;
    }
    if (_detailsDirty && !await _saveDetails(quiet: true)) return;
    final problems = _app!.problems;
    if (problems.isNotEmpty) {
      _toast('Still needed: ${problems.join(', ')}', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final app = await _service.submit(widget.token);
      setState(() => _app = app);
    } catch (e) {
      _toast(ApplicationService.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: _app == null
            ? Center(
                child: _loadError == null
                    ? const CircularProgressIndicator()
                    : _Message(
                        icon: Icons.link_off,
                        color: AppTheme.errorColor,
                        title: 'Link not working',
                        body: _loadError!,
                        action: TextButton(
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ),
              )
            : _content(_app!),
      ),
    );
  }

  Widget _content(ApplicantApplication app) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(app),
              const SizedBox(height: 16),
              if (app.onboarding != null)
                OnboardingSection(
                  token: widget.token,
                  app: app,
                  onUpdated: (updated) => setState(() => _app = updated),
                )
              else
                ..._statusBanner(app),
              // When changes were requested, the documents to fix come
              // first instead of below the long details form.
              if (app.isOpen &&
                  app.status == ApplicationStatus.needsChanges) ...[
                _documentsCard(app),
                const SizedBox(height: 16),
                _detailsCard(),
                const SizedBox(height: 16),
                _submitCard(app),
              ] else if (app.isOpen) ...[
                _detailsCard(),
                const SizedBox(height: 16),
                _documentsCard(app),
                const SizedBox(height: 16),
                _submitCard(app),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ApplicantApplication app) => Row(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('assets/app_icon.jpg', width: 52, height: 52),
      ),
      const SizedBox(width: 14),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mega Homecare Inc.',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 2),
            Text(
              'Caregiver application',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    ],
  );

  List<Widget> _statusBanner(ApplicantApplication app) {
    Widget banner(
      IconData icon,
      Color color,
      String title,
      String body, {
      Widget? extra,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _Card(
        color: color.withValues(alpha: 0.07),
        borderColor: color.withValues(alpha: 0.35),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(fontSize: 14, height: 1.45),
                  ),
                  ?extra,
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final first = app.fullName.split(' ').first;
    switch (app.status) {
      case ApplicationStatus.submitted:
        return [
          banner(
            Icons.check_circle,
            AppTheme.successColor,
            'Thank you${first.isEmpty ? '' : ', $first'}!',
            'Your application has been submitted. Mega Homecare will review your documents and contact you. If anything needs to be changed, you will get an email and can use this same link.',
          ),
        ];
      case ApplicationStatus.accepted:
        return [
          banner(
            Icons.verified,
            AppTheme.successColor,
            'Your application was accepted',
            'Welcome to Mega Homecare! We will send your onboarding documents to sign soon.',
          ),
        ];
      case ApplicationStatus.rejected:
        return [
          banner(
            Icons.info_outline,
            AppTheme.textSecondary,
            'This application is closed',
            'Please contact Mega Homecare if you have any questions.',
          ),
        ];
      case ApplicationStatus.needsChanges:
        final flagged = app.requiredDocuments
            .where((d) => app.doc(d.id).status == DocStatus.needsChanges)
            .toList();
        return [
          banner(
            Icons.edit_note,
            AppTheme.warningColor,
            'Some changes are needed',
            app.generalComment.isNotEmpty
                ? app.generalComment
                : 'Please look at the notes below, fix them, and press Submit again.',
            extra: flagged.isEmpty
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Upload again: ${flagged.map((d) => d.label).join(', ')}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ];
      default:
        return [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Hi${first.isEmpty ? '' : ' $first'}, please fill in your details and upload each document below, then press Submit. '
              'You can stop and come back to this link any time — what you have done is saved.',
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
        ];
    }
  }

  // ── Step 1: details ──

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? keyboard,
    bool email = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard ?? (email ? TextInputType.emailAddress : null),
        textCapitalization: keyboard == null && !email
            ? TextCapitalization.words
            : TextCapitalization.none,
        onChanged: (_) => _detailsDirty = true,
        decoration: InputDecoration(labelText: label),
        validator: (v) {
          final t = v?.trim() ?? '';
          if (t.isEmpty) return 'Required';
          if (email && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t)) {
            return 'Enter a valid email';
          }
          return null;
        },
      ),
    );
  }

  Widget _contactFields(_ContactControllers c) => Column(
    children: [
      _field(c.name, 'Full name'),
      _field(c.relation, 'Relationship (e.g. sister, former manager)'),
      _field(c.phone, 'Phone number', keyboard: TextInputType.phone),
      _field(c.email, 'Email', email: true),
    ],
  );

  Widget _detailsCard() {
    return _Card(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StepTitle(number: 1, title: 'Your details'),
            _field(_fullName, 'Full legal name'),
            _field(_email, 'Email', email: true),
            _field(_phone, 'Phone number', keyboard: TextInputType.phone),
            const _SubTitle('Emergency contact'),
            _contactFields(_emergency),
            for (int i = 0; i < 2; i++) ...[
              _SubTitle('Professional reference ${i + 1}'),
              _contactFields(_references[i]),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _saveDetails(),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: documents ──

  Widget _documentsCard(ApplicantApplication app) {
    final done = app.requiredDocuments.where((d) {
      final s = app.doc(d.id).status;
      return s == DocStatus.uploaded || s == DocStatus.approved;
    }).length;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepTitle(
            number: 2,
            title: 'Documents',
            trailing: '$done of ${app.requiredDocuments.length}',
          ),
          const Text(
            'All documents are required. A clear photo from your phone is fine.',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          for (final d in app.requiredDocuments) _documentRow(d, app.doc(d.id)),
        ],
      ),
    );
  }

  Widget _documentRow(RequiredDocument d, ApplicationDocument doc) {
    final uploading = _uploading.contains(d.id);
    final (Color color, IconData icon, String status) = switch (doc.status) {
      DocStatus.approved => (AppTheme.successColor, Icons.verified, 'Approved'),
      DocStatus.uploaded => (
        AppTheme.primaryColor,
        Icons.check_circle,
        'Uploaded',
      ),
      DocStatus.needsChanges => (
        AppTheme.warningColor,
        Icons.error,
        'Please upload again',
      ),
      _ => (
        AppTheme.textSecondary,
        Icons.radio_button_unchecked,
        'Not uploaded',
      ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: doc.status == DocStatus.needsChanges
            ? AppTheme.warningColor.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: doc.status == DocStatus.needsChanges
              ? AppTheme.warningColor.withValues(alpha: 0.5)
              : const Color(0xFFE3E8EF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      doc.hasFile ? '$status · ${doc.fileName}' : status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: color),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (doc.status != DocStatus.approved)
                uploading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : doc.status == DocStatus.missing ||
                          doc.status == DocStatus.needsChanges
                    ? FilledButton.icon(
                        onPressed: () => _pickAndUpload(d),
                        icon: const Icon(Icons.upload, size: 18),
                        label: const Text('Upload'),
                      )
                    : OutlinedButton(
                        onPressed: () => _pickAndUpload(d),
                        child: const Text('Replace'),
                      ),
            ],
          ),
          if (d.hint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 4),
              child: Text(
                d.hint,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          if (doc.status == DocStatus.needsChanges && doc.comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 8),
              child: Text(
                'Note from Mega Homecare: ${doc.comment}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Step 3: submit ──

  Widget _submitCard(ApplicantApplication app) {
    final problems = app.problems;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepTitle(number: 3, title: 'Submit'),
          Text(
            problems.isEmpty
                ? 'Everything is ready. Press Submit to send your application to Mega Homecare.'
                : 'Still needed: ${problems.join(', ')}.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: problems.isEmpty
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _submitting || _uploading.isNotEmpty ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      app.status == ApplicationStatus.needsChanges
                          ? 'Submit again'
                          : 'Submit application',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactControllers {
  final name = TextEditingController();
  final relation = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();

  void fill(Contact c) {
    name.text = c.name;
    relation.text = c.relation;
    phone.text = c.phone;
    email.text = c.email;
  }

  Contact get value => Contact(
    name: name.text.trim(),
    relation: relation.text.trim(),
    phone: phone.text.trim(),
    email: email.text.trim(),
  );

  void dispose() {
    for (final c in [name, relation, phone, email]) {
      c.dispose();
    }
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color borderColor;

  const _Card({
    required this.child,
    this.color = Colors.white,
    this.borderColor = const Color(0xFFE3E8EF),
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor),
    ),
    child: child,
  );
}

class _StepTitle extends StatelessWidget {
  final int number;
  final String title;
  final String? trailing;

  const _StepTitle({required this.number, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppTheme.primaryColor,
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
      ],
    ),
  );
}

class _SubTitle extends StatelessWidget {
  final String text;
  const _SubTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppTheme.primaryColor,
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final Widget? action;

  const _Message({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 44, color: color),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14.5,
            color: AppTheme.textSecondary,
            height: 1.45,
          ),
        ),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    ),
  );
}
