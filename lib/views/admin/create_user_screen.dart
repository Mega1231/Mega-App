import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/create_user_viewmodel.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/custom_text_field.dart';

class CreateUserScreen extends StatefulWidget {
  final String userType; // 'Client' or 'Caregiver'
  final AppUser? existingUser; // If set, we're editing

  const CreateUserScreen({
    super.key,
    required this.userType,
    this.existingUser,
  });

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  File? _selectedPhoto;
  double? _selectedLat;
  double? _selectedLng;

  // Address autocomplete
  final _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  List<_PlaceSuggestion> _suggestions = [];
  bool _isSearchingAddress = false;
  bool _isSelectingSuggestion = false;
  Timer? _debounce;

  // Client note file
  File? _selectedNoteFile;
  String _selectedNoteFileName = '';

  // Family members (max 3, for clients only)
  final List<TextEditingController> _familyNameControllers = [];
  final List<TextEditingController> _familyUsernameControllers = [];

  // Edit mode
  bool get _isEditMode => widget.existingUser != null;
  final AuthService _authService = AuthService();
  List<AppUser> _existingFamilyMembers = [];
  bool _loadingFamily = false;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final user = widget.existingUser!;
      _fullNameController.text = user.fullName;
      _addressController.text = user.address;
      _emergencyController.text = user.emergencyContact;
      _selectedLat = user.latitude;
      _selectedLng = user.longitude;
      _selectedNoteFileName = user.clientNoteFileName;
      if (widget.userType == 'Client') {
        _loadExistingFamilyMembers();
      }
    }
  }

  Future<void> _loadExistingFamilyMembers() async {
    setState(() => _loadingFamily = true);
    try {
      _existingFamilyMembers =
          await _authService.getFamilyMembers(widget.existingUser!.uid);
    } catch (e) {
      debugPrint('Error loading family members: $e');
    }
    if (mounted) setState(() => _loadingFamily = false);
  }

  void _addFamilyMember() {
    if ((_existingFamilyMembers.length + _familyNameControllers.length) >= 3) {
      return;
    }
    setState(() {
      _familyNameControllers.add(TextEditingController());
      _familyUsernameControllers.add(TextEditingController());
    });
  }

  void _removeFamilyMember(int index) {
    setState(() {
      _familyNameControllers[index].dispose();
      _familyUsernameControllers[index].dispose();
      _familyNameControllers.removeAt(index);
      _familyUsernameControllers.removeAt(index);
    });
  }

  Future<void> _deleteExistingFamilyMember(AppUser member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Family Member'),
        content: Text('Remove ${member.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _authService.deleteFamilyMember(
          member.uid, widget.existingUser!.uid);
      _loadExistingFamilyMembers();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.error(
          context: context,
          message: 'Failed to remove: $e',
        );
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _addressController.dispose();
    _emergencyController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    for (final c in _familyNameControllers) {
      c.dispose();
    }
    for (final c in _familyUsernameControllers) {
      c.dispose();
    }
    _debounce?.cancel();
    super.dispose();
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Choose Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPickerOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: AppTheme.primaryColor,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildPickerOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: AppTheme.successColor,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  if (_selectedPhoto != null)
                    _buildPickerOption(
                      icon: Icons.delete_rounded,
                      label: 'Remove',
                      color: AppTheme.errorColor,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _selectedPhoto = null);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );
    if (picked != null) {
      setState(() => _selectedPhoto = File(picked.path));
    }
  }

  void _onAddressChanged(String query) {
    if (_isSelectingSuggestion) return;
    // Clear previous selection when user edits
    if (_selectedLat != null) {
      setState(() {
        _selectedLat = null;
        _selectedLng = null;
      });
    }
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchSuggestions(query.trim());
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (_apiKey.isEmpty) return;
    setState(() => _isSearchingAddress = true);

    try {
      final url = Uri.parse(
        'https://places.googleapis.com/v1/places:autocomplete',
      );
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
        },
        body: json.encode({'input': query}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final suggestions = (data['suggestions'] as List?) ?? [];
        setState(() {
          _suggestions = suggestions
              .where((s) => s['placePrediction'] != null)
              .map((s) {
                final p = s['placePrediction'];
                return _PlaceSuggestion(
                  placeId: p['placeId'] ?? '',
                  description: p['text']?['text'] ?? '',
                );
              })
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Places autocomplete error: $e');
    }
    if (mounted) setState(() => _isSearchingAddress = false);
  }

  Future<void> _selectSuggestion(_PlaceSuggestion suggestion) async {
    _isSelectingSuggestion = true;
    setState(() {
      _suggestions = [];
      _isSearchingAddress = true;
    });

    try {
      final url = Uri.parse(
        'https://places.googleapis.com/v1/places/${suggestion.placeId}',
      );
      final response = await http.get(
        url,
        headers: {
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'formattedAddress,location',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address =
            data['formattedAddress'] as String? ?? suggestion.description;
        final location = data['location'];
        if (location != null) {
          setState(() {
            _addressController.text = address;
            _selectedLat = (location['latitude'] as num).toDouble();
            _selectedLng = (location['longitude'] as num).toDouble();
          });
        }
      }
    } catch (e) {
      debugPrint('Place details error: $e');
    }
    _isSelectingSuggestion = false;
    if (mounted) setState(() => _isSearchingAddress = false);
    FocusScope.of(context).unfocus();
  }

  IconData _getNoteFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (['jpg', 'jpeg', 'png'].contains(ext)) return Icons.image;
    if (['doc', 'docx'].contains(ext)) return Icons.description;
    return Icons.insert_drive_file;
  }

  Future<void> _pickNoteFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedNoteFile = File(result.files.single.path!);
        _selectedNoteFileName = result.files.single.name;
      });
    }
  }

  bool _isCreating = false;

  Future<void> _submitForm(CreateUserViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;
    if (_isCreating) return;

    setState(() => _isCreating = true);

    if (_isEditMode) {
      await _updateUser(vm);
    } else {
      await _createNewUser(vm);
    }
  }

  Future<void> _updateUser(CreateUserViewModel vm) async {
    try {
      await _authService.updateUser(
        uid: widget.existingUser!.uid,
        fullName: _fullNameController.text.trim(),
        address: _addressController.text.trim(),
        latitude: _selectedLat,
        longitude: _selectedLng,
        emergencyContact: _emergencyController.text.trim(),
        photo: _selectedPhoto,
        noteFile: _selectedNoteFile,
        noteFileName:
            _selectedNoteFile != null ? _selectedNoteFileName : null,
      );

      // Create any new family members
      if (widget.userType == 'Client' && _familyNameControllers.isNotEmpty) {
        int created = 0;
        int total = 0;
        for (int i = 0; i < _familyNameControllers.length; i++) {
          final name = _familyNameControllers[i].text.trim();
          final username = _familyUsernameControllers[i].text.trim();
          if (name.isEmpty || username.isEmpty) continue;
          total++;
          try {
            await _authService.createFamilyMember(
              username: username,
              password: 'changeme123',
              fullName: name,
              linkedClientId: widget.existingUser!.uid,
            );
            created++;
          } catch (e) {
            debugPrint('Failed to create family member: $e');
          }
        }
        if (!mounted) return;
        if (total > 0 && created < total) {
          CustomSnackbar.success(
            context: context,
            message:
                'Profile updated! $created of $total new family members added.',
          );
          Navigator.pop(context, true);
          return;
        }
      }

      if (!mounted) return;
      CustomSnackbar.success(
        context: context,
        message: 'Profile updated successfully!',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      CustomSnackbar.error(
        context: context,
        message: 'Failed to update: $e',
      );
    }
  }

  Future<void> _createNewUser(CreateUserViewModel vm) async {
    final role = widget.userType.toLowerCase();

    final success = await vm.createUser(
      username: _usernameController.text,
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
      role: role,
      address: _addressController.text.trim(),
      latitude: _selectedLat,
      longitude: _selectedLng,
      emergencyContact: _emergencyController.text.trim(),
      photo: _selectedPhoto,
      noteFile: _selectedNoteFile,
      noteFileName: _selectedNoteFileName,
    );

    if (!mounted) return;

    if (!success) {
      setState(() => _isCreating = false);
      CustomSnackbar.error(
        context: context,
        message: vm.error ?? 'Failed to create user.',
      );
      return;
    }

    // Create family members if any were added (client only)
    if (widget.userType == 'Client' && _familyNameControllers.isNotEmpty) {
      final password = _passwordController.text;
      int created = 0;
      int total = 0;
      for (int i = 0; i < _familyNameControllers.length; i++) {
        final name = _familyNameControllers[i].text.trim();
        final username = _familyUsernameControllers[i].text.trim();
        if (name.isEmpty || username.isEmpty) continue;
        total++;

        final familySuccess = await vm.createFamilyMember(
          username: username,
          password: password,
          fullName: name,
        );
        if (familySuccess) created++;
      }
      if (!mounted) return;
      if (total > 0 && created < total) {
        CustomSnackbar.success(
          context: context,
          message:
              'Client created! $created of $total family members added.',
        );
        Navigator.pop(context, true);
        return;
      }
    }

    if (!mounted) return;
    CustomSnackbar.success(
      context: context,
      message: '${widget.userType} created successfully!',
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreateUserViewModel(),
      child: Consumer<CreateUserViewModel>(
        builder: (context, vm, _) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                _isEditMode
                    ? 'Edit ${widget.userType}'
                    : 'Create ${widget.userType}',
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo picker
                    Center(
                      child: GestureDetector(
                        onTap: _showImagePickerSheet,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 55,
                              backgroundColor: AppTheme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              backgroundImage: _selectedPhoto != null
                                  ? FileImage(_selectedPhoto!)
                                  : (_isEditMode &&
                                          widget.existingUser!.photoUrl
                                              .isNotEmpty)
                                      ? NetworkImage(
                                          widget.existingUser!.photoUrl)
                                      : null,
                              child: _selectedPhoto == null &&
                                      (!_isEditMode ||
                                          widget.existingUser!.photoUrl.isEmpty)
                                  ? _isEditMode
                                      ? Text(
                                          widget.existingUser!.fullName
                                                  .isNotEmpty
                                              ? widget
                                                  .existingUser!.fullName[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            fontSize: 40,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryColor,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person,
                                          size: 50,
                                          color: AppTheme.primaryColor,
                                        )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _isEditMode ? 'Tap to change photo' : 'Tap to add photo',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    const Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    CustomTextField(
                      controller: _fullNameController,
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person_outline),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    if (widget.userType == 'Client') ...[
                      CustomTextField(
                        controller: _addressController,
                        labelText: 'Client Address *',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        suffixIcon: _isSearchingAddress
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                        onChanged: _onAddressChanged,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Address is required for clients';
                          }
                          if (_selectedLat == null || _selectedLng == null) {
                            return 'Please select an address from suggestions';
                          }
                          return null;
                        },
                      ),
                      if (_suggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _suggestions.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, indent: 44),
                            itemBuilder: (_, i) {
                              final s = _suggestions[i];
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.location_on,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                                title: Text(
                                  s.description,
                                  style: const TextStyle(fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _selectSuggestion(s),
                              );
                            },
                          ),
                        ),
                      if (_selectedLat != null && _selectedLng != null) ...[
                        const SizedBox(height: 6),
                        const Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: AppTheme.successColor,
                            ),
                            SizedBox(width: 6),
                          ],
                        ),
                      ],
                    ] else ...[
                      CustomTextField(
                        controller: _addressController,
                        labelText: 'Address',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        maxLines: 2,
                      ),
                    ],
                    const SizedBox(height: 16),

                    CustomTextField(
                      controller: _emergencyController,
                      labelText: 'Emergency Contact',
                      prefixIcon: const Icon(Icons.emergency_outlined),
                    ),

                    // Client note file upload
                    if (widget.userType == 'Client') ...[
                      const SizedBox(height: 28),
                      const Text(
                        'Care Plan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Upload the care plan document for this client',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _pickNoteFile,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _selectedNoteFile != null
                                ? AppTheme.successColor.withValues(alpha: 0.05)
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _selectedNoteFile != null
                                  ? AppTheme.successColor.withValues(alpha: 0.4)
                                  : Colors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                          child: _selectedNoteFile != null
                              ? Row(
                                  children: [
                                    Icon(
                                      _getNoteFileIcon(_selectedNoteFileName),
                                      color: AppTheme.primaryColor,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedNoteFileName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          const Text(
                                            'Tap to change file',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close,
                                          size: 20, color: AppTheme.errorColor),
                                      onPressed: () => setState(() {
                                        _selectedNoteFile = null;
                                        _selectedNoteFileName = '';
                                      }),
                                    ),
                                  ],
                                )
                              : (_isEditMode &&
                                      widget.existingUser!.clientNoteFileName
                                          .isNotEmpty &&
                                      _selectedNoteFileName.isNotEmpty)
                                  ? Row(
                                      children: [
                                        Icon(
                                          _getNoteFileIcon(
                                              _selectedNoteFileName),
                                          color: AppTheme.primaryColor,
                                          size: 28,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Current: $_selectedNoteFileName',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              const Text(
                                                'Tap to replace file',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppTheme.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                  children: [
                                    Icon(
                                      Icons.upload_file_rounded,
                                      size: 36,
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Tap to upload file',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'PDF, DOC, DOCX, JPG, PNG',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],

                    // Family Members section (Client only)
                    if (widget.userType == 'Client') ...[
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Family Members',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if ((_existingFamilyMembers.length +
                                  _familyNameControllers.length) <
                              3)
                            TextButton.icon(
                              onPressed: _addFamilyMember,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        _isEditMode
                            ? 'Add up to 3 family members who can chat with the caregiver'
                            : 'Add up to 3 family members who can chat with the caregiver (same password as client)',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Existing family members (edit mode)
                      if (_isEditMode && _loadingFamily)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      if (_isEditMode && !_loadingFamily)
                        ..._existingFamilyMembers.map((m) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor
                                    .withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppTheme.successColor
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppTheme.successColor
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      size: 20,
                                      color: AppTheme.successColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                    onTap: () =>
                                        _deleteExistingFamilyMember(m),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: AppTheme.errorColor
                                            .withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),

                      // New family members to add
                      ...List.generate(_familyNameControllers.length, (i) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor
                                .withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppTheme.primaryColor
                                  .withValues(alpha: 0.12),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${i + 1}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Family Member ${i + 1}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => _removeFamilyMember(i),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: AppTheme.errorColor
                                            .withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              CustomTextField(
                                controller: _familyNameControllers[i],
                                labelText: 'Full Name',
                                prefixIcon:
                                    const Icon(Icons.person_outline),
                                validator: (v) => v == null ||
                                        v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                              const SizedBox(height: 10),
                              CustomTextField(
                                controller:
                                    _familyUsernameControllers[i],
                                labelText: 'Username',
                                prefixIcon:
                                    const Icon(Icons.alternate_email),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  if (v.trim().contains(' ')) {
                                    return 'No spaces allowed';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      if (_familyNameControllers.isEmpty &&
                          _existingFamilyMembers.isEmpty &&
                          !_loadingFamily)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.family_restroom,
                                size: 32,
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'No family members added',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],

                    // Login Credentials (only for create mode)
                    if (!_isEditMode) ...[
                      const SizedBox(height: 28),

                      const Text(
                        'Login Credentials',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        controller: _usernameController,
                        labelText: 'Username',
                        prefixIcon: const Icon(Icons.alternate_email),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (v.trim().contains(' ')) {
                            return 'Username cannot contain spaces';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        controller: _passwordController,
                        labelText: 'Password',
                        obscureText: _obscurePassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 6) return 'Minimum 6 characters';
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 32),

                    CustomButton(
                      text: _isEditMode
                          ? 'Save Changes'
                          : 'Create ${widget.userType}',
                      onTap: () => _submitForm(vm),
                      isLoading: _isCreating,
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlaceSuggestion {
  final String placeId;
  final String description;

  _PlaceSuggestion({required this.placeId, required this.description});
}
