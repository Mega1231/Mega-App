import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/places_service.dart';
import '../../theme/app_theme.dart';
import '../web_widgets.dart';

/// Opens the add/edit dialog for a client or caregiver. Resolves to true
/// when something was saved.
Future<bool> showWebUserForm(
  BuildContext context, {
  required String role,
  AppUser? user,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _WebUserFormDialog(role: role, user: user),
  );
  return saved == true;
}

class _NewFamilyMember {
  final name = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();

  void dispose() {
    name.dispose();
    username.dispose();
    password.dispose();
  }
}

class _WebUserFormDialog extends StatefulWidget {
  final String role;
  final AppUser? user;

  const _WebUserFormDialog({required this.role, this.user});

  @override
  State<_WebUserFormDialog> createState() => _WebUserFormDialogState();
}

class _WebUserFormDialogState extends State<_WebUserFormDialog> {
  static const _maxFamily = 3;

  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  final _places = PlacesService();

  late final _name = TextEditingController(text: widget.user?.fullName);
  late final _phone = TextEditingController(text: widget.user?.phone);
  late final _emergency =
      TextEditingController(text: widget.user?.emergencyContact);
  late final _address = TextEditingController(text: widget.user?.address);
  final _username = TextEditingController();
  final _password = TextEditingController();

  late double? _lat = widget.user?.latitude;
  late double? _lng = widget.user?.longitude;
  List<PlaceSuggestion> _suggestions = [];
  bool _searching = false;
  Timer? _debounce;

  Uint8List? _photoBytes;
  Uint8List? _noteBytes;
  String? _noteName;

  List<AppUser> _existingFamily = [];
  late bool _loadingFamily = _isEdit && _isClient;
  final List<_NewFamilyMember> _newFamily = [];

  bool _saving = false;
  bool _obscure = true;
  String? _error;

  bool get _isEdit => widget.user != null;
  bool get _isClient => widget.role == 'client';
  String get _noun => _isClient ? 'Client' : 'Caregiver';

  @override
  void initState() {
    super.initState();
    if (_isEdit && _isClient) _loadFamily();
  }

  Future<void> _loadFamily() async {
    try {
      final members = await _auth.getFamilyMembers(widget.user!.uid);
      if (mounted) setState(() => _existingFamily = members);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load family members: $e');
    }
    if (mounted) setState(() => _loadingFamily = false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_name, _phone, _emergency, _address, _username, _password]) {
      c.dispose();
    }
    for (final f in _newFamily) {
      f.dispose();
    }
    super.dispose();
  }

  // ── Address search (clients) ──

  void _onAddressChanged(String value) {
    if (!_isClient) return;
    setState(() {
      _lat = null;
      _lng = null;
    });
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _searching = true);
      try {
        final results = await _places.autocomplete(value);
        if (mounted) setState(() => _suggestions = results);
      } catch (_) {
        if (mounted) setState(() => _suggestions = []);
      }
      if (mounted) setState(() => _searching = false);
    });
  }

  Future<void> _pickSuggestion(PlaceSuggestion s) async {
    setState(() {
      _suggestions = [];
      _searching = true;
    });
    try {
      final d = await _places.details(s);
      if (d != null && mounted) {
        setState(() {
          _address.text = d.address;
          _lat = d.latitude;
          _lng = d.longitude;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _searching = false);
  }

  // ── Files ──

  Future<void> _pickPhoto() async {
    final result = await FilePicker
        .pickFiles(type: FileType.image, withData: true);
    final file = result?.files.single;
    if (file?.bytes != null) setState(() => _photoBytes = file!.bytes);
  }

  Future<void> _pickCarePlan() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes != null) {
      setState(() {
        _noteBytes = file!.bytes;
        _noteName = file.name;
      });
    }
  }

  // ── Family ──

  int get _familyCount => _existingFamily.length + _newFamily.length;

  Future<void> _removeExistingFamily(AppUser member) async {
    final ok = await webConfirm(
      context,
      title: 'Remove ${member.fullName}?',
      message:
          'Their family login will be closed and they will no longer see ${widget.user!.fullName}\'s care team.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _auth.deleteFamilyMember(member.uid, widget.user!.uid);
      setState(() => _existingFamily.remove(member));
    } catch (e) {
      setState(() => _error = 'Could not remove ${member.fullName}: $e');
    }
  }

  // ── Save ──

  String _authError(Object e) {
    final m = e.toString();
    if (m.contains('username-exists') || m.contains('email-already-in-use')) {
      return 'That username is already taken.';
    }
    if (m.contains('weak-password')) {
      return 'Password must be at least 6 characters.';
    }
    if (e is FirebaseAuthException && e.message != null) return e.message!;
    return m;
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_isClient && (_lat == null || _lng == null)) {
      setState(() => _error =
          'Choose the client address from the suggestions so clock-in can verify the location.');
      return;
    }

    setState(() => _saving = true);
    final failedFamily = <String>[];
    try {
      final String uid;
      if (_isEdit) {
        uid = widget.user!.uid;
        await _auth.updateUser(
          uid: uid,
          fullName: _name.text.trim(),
          address: _address.text.trim(),
          latitude: _lat,
          longitude: _lng,
          emergencyContact: _emergency.text.trim(),
          phone: _phone.text.trim(),
          photoBytes: _photoBytes,
          noteBytes: _noteBytes,
          noteFileName: _noteName,
        );
      } else {
        uid = await _auth.createUser(
          username: _username.text.trim(),
          password: _password.text,
          fullName: _name.text.trim(),
          role: widget.role,
          phone: _phone.text.trim(),
          address: _address.text.trim(),
          latitude: _lat,
          longitude: _lng,
          emergencyContact: _emergency.text.trim(),
          photoBytes: _photoBytes,
          noteBytes: _noteBytes,
          noteFileName: _noteName ?? '',
        );
      }

      for (final f in _newFamily) {
        try {
          await _auth.createFamilyMember(
            username: f.username.text.trim(),
            // New client: family shares the client's password (as on mobile).
            password: _isEdit ? f.password.text : _password.text,
            fullName: f.name.text.trim(),
            linkedClientId: uid,
          );
        } catch (e) {
          failedFamily.add('${f.name.text.trim()} (${_authError(e)})');
        }
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = _authError(e);
      });
      return;
    }

    if (!mounted) return;
    if (failedFamily.isNotEmpty) {
      webToast(
        context,
        '$_noun saved, but these family members were not added: ${failedFamily.join(', ')}',
        error: true,
      );
    } else {
      webToast(context, '$_noun ${_isEdit ? 'updated' : 'created'}');
    }
    Navigator.pop(context, true);
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 1000;
    final left = _personalSection();
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _photoSection(),
        if (_isClient) ...[
          const SizedBox(height: 20),
          _carePlanSection(),
        ],
      ],
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 860),
        child: Column(
          children: [
            _header(),
            const Divider(height: 1, color: WebTokens.border),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: left),
                            const SizedBox(width: 28),
                            Expanded(flex: 2, child: right),
                          ],
                        )
                      else ...[
                        left,
                        const SizedBox(height: 20),
                        right,
                      ],
                      if (!_isEdit) ...[
                        const SizedBox(height: 28),
                        _loginSection(),
                      ],
                      if (_isClient) ...[
                        const SizedBox(height: 28),
                        _familySection(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: WebTokens.border),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(28, 20, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEdit ? 'Edit ${widget.user!.fullName}' : 'Add $_noun',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  if (_isEdit)
                    Text(
                      '@${widget.user!.username}',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );

  Widget _footer() => Padding(
        padding: const EdgeInsets.fromLTRB(28, 14, 28, 14),
        child: Row(
          children: [
            if (_error != null)
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 18, color: AppTheme.errorColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.errorColor),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Spacer(),
            const SizedBox(width: 16),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEdit ? 'Save changes' : 'Create $_noun'),
            ),
          ],
        ),
      );

  Widget _sectionTitle(String title, [String? subtitle]) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
              ),
          ],
        ),
      );

  InputDecoration _dec(String label, {String? hint, Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: WebTokens.border),
        ),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Required' : null;

  Widget _personalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Personal information'),
        TextFormField(
          controller: _name,
          decoration: _dec('Full name *'),
          validator: _required,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _phone,
                decoration: _dec('Phone'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: _emergency,
                decoration: _dec('Emergency contact'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _address,
          onChanged: _onAddressChanged,
          decoration: _dec(
            _isClient ? 'Client address *' : 'Address',
            hint: _isClient ? 'Start typing and pick a suggestion' : null,
            suffix: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : (_isClient && _lat != null)
                    ? const Tooltip(
                        message: 'Location verified',
                        child: Icon(Icons.verified,
                            color: AppTheme.successColor, size: 20),
                      )
                    : null,
          ),
          validator: _isClient ? _required : null,
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: WebTokens.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                for (final s in _suggestions)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined, size: 18),
                    title: Text(s.description,
                        style: const TextStyle(fontSize: 13)),
                    onTap: () => _pickSuggestion(s),
                  ),
              ],
            ),
          ),
        if (_isClient && !_places.isConfigured)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Address search is not configured for this build (MAPS_WEB_API_KEY missing).',
              style: TextStyle(fontSize: 12, color: AppTheme.errorColor),
            ),
          ),
      ],
    );
  }

  Widget _photoSection() {
    final existing = widget.user?.photoUrl ?? '';
    final hasPhoto = _photoBytes != null || existing.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Photo'),
        WebCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _photoBytes != null
                  ? ClipOval(
                      child: Image.memory(_photoBytes!,
                          width: 68, height: 68, fit: BoxFit.cover),
                    )
                  : WebAvatar(
                      name: _name.text,
                      photoUrl: existing,
                      size: 68,
                      placeholderIcon: Icons.person_outline,
                    ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickPhoto,
                      icon: const Icon(Icons.upload_outlined, size: 18),
                      label: Text(hasPhoto ? 'Change photo' : 'Upload photo'),
                    ),
                    const SizedBox(height: 4),
                    const Text('JPG or PNG',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _carePlanSection() {
    final existingName = widget.user?.clientNoteFileName ?? '';
    final existingUrl = widget.user?.clientNoteUrl ?? '';
    final name = _noteName ?? (existingName.isNotEmpty ? existingName : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Care plan', 'PDF, Word or image'),
        WebCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                name == null
                    ? Icons.note_add_outlined
                    : Icons.description_outlined,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name ?? 'No care plan uploaded',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: name == null
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                  ),
                ),
              ),
              if (_noteName == null && existingUrl.isNotEmpty)
                TextButton(
                  onPressed: () => launchUrl(Uri.parse(existingUrl)),
                  child: const Text('Open'),
                ),
              TextButton(
                onPressed: _pickCarePlan,
                child: Text(name == null ? 'Upload' : 'Replace'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _loginSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'Login',
          _isClient
              ? 'Family members added below use this same password.'
              : 'The caregiver signs in to the mobile app with these.',
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _username,
                decoration: _dec('Username *'),
                validator: _required,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: _dec(
                  'Password *',
                  suffix: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => v == null || v.length < 6
                    ? 'At least 6 characters'
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _familySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionTitle(
                'Family members',
                'Up to $_maxFamily. They can chat with and call the care team.',
              ),
            ),
            if (!_loadingFamily && _familyCount < _maxFamily)
              TextButton.icon(
                onPressed: () =>
                    setState(() => _newFamily.add(_NewFamilyMember())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add family member'),
              ),
          ],
        ),
        for (final m in _existingFamily)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: WebCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  WebAvatar(name: m.fullName, photoUrl: m.photoUrl, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${m.fullName}  ·  @${m.username}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _removeExistingFamily(m),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.errorColor),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            ),
          ),
        for (final f in _newFamily)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: f.name,
                    decoration: _dec('Family member name *'),
                    validator: _required,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: f.username,
                    decoration: _dec('Username *'),
                    validator: _required,
                  ),
                ),
                if (_isEdit) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: f.password,
                      obscureText: true,
                      decoration: _dec('Password *'),
                      validator: (v) => v == null || v.length < 6
                          ? 'At least 6 characters'
                          : null,
                    ),
                  ),
                ],
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () => setState(() {
                    _newFamily.remove(f);
                    f.dispose();
                  }),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
          ),
        if (_loadingFamily)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Text('Loading family members…',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          )
        else if (_existingFamily.isEmpty && _newFamily.isEmpty)
          const Text(
            'No family members yet.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
      ],
    );
  }
}
