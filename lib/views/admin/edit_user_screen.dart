import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/custom_text_field.dart';

class EditUserScreen extends StatefulWidget {
  final AppUser user;

  const EditUserScreen({super.key, required this.user});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  late final TextEditingController _fullNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _emergencyController;
  late final TextEditingController _phoneController;

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

  bool _isSaving = false;

  bool get _isClient => widget.user.role == 'client';

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _addressController = TextEditingController(text: widget.user.address);
    _emergencyController =
        TextEditingController(text: widget.user.emergencyContact);
    _phoneController = TextEditingController(text: widget.user.phone);
    _selectedLat = widget.user.latitude;
    _selectedLng = widget.user.longitude;
    _selectedNoteFileName = widget.user.clientNoteFileName;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _addressController.dispose();
    _emergencyController.dispose();
    _phoneController.dispose();
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
                  if (_selectedPhoto != null ||
                      widget.user.photoUrl.isNotEmpty)
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
      final url =
          Uri.parse('https://places.googleapis.com/v1/places:autocomplete');
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      await _authService.updateUser(
        uid: widget.user.uid,
        fullName: _fullNameController.text.trim(),
        address: _addressController.text.trim(),
        latitude: _selectedLat,
        longitude: _selectedLng,
        emergencyContact: _emergencyController.text.trim(),
        phone: _phoneController.text.trim(),
        photo: _selectedPhoto,
        noteFile: _selectedNoteFile,
        noteFileName:
            _selectedNoteFile != null ? _selectedNoteFileName : null,
      );

      if (!mounted) return;
      CustomSnackbar.success(
        context: context,
        message: 'Profile updated successfully!',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      CustomSnackbar.error(
        context: context,
        message: 'Failed to update: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel =
        widget.user.role[0].toUpperCase() + widget.user.role.substring(1);

    return Scaffold(
      appBar: AppBar(title: Text('Edit $roleLabel')),
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
                        backgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 0.1),
                        backgroundImage: _selectedPhoto != null
                            ? FileImage(_selectedPhoto!)
                            : widget.user.photoUrl.isNotEmpty
                                ? NetworkImage(widget.user.photoUrl)
                                : null,
                        child: _selectedPhoto == null &&
                                widget.user.photoUrl.isEmpty
                            ? Text(
                                widget.user.fullName.isNotEmpty
                                    ? widget.user.fullName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
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
              const Center(
                child: Text(
                  'Tap to change photo',
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

              if (_isClient) ...[
                // Client address with autocomplete
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
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                const SizedBox(height: 16),
              ] else ...[
                // Caregiver address (plain text)
                CustomTextField(
                  controller: _addressController,
                  labelText: 'Address',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _phoneController,
                  labelText: 'Phone',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
              ],

              CustomTextField(
                controller: _emergencyController,
                labelText: 'Emergency Contact',
                prefixIcon: const Icon(Icons.emergency_outlined),
              ),
              const SizedBox(height: 24),

              // Care plan file (clients only)
              if (_isClient) ...[
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

                if (_selectedNoteFile != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            AppTheme.successColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getNoteFileIcon(_selectedNoteFileName),
                          color: AppTheme.successColor,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedNoteFileName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            _selectedNoteFile = null;
                            _selectedNoteFileName = '';
                          }),
                          child: const Icon(Icons.close,
                              size: 18, color: AppTheme.errorColor),
                        ),
                      ],
                    ),
                  )
                else if (widget.user.clientNoteUrl.isNotEmpty &&
                    _selectedNoteFileName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            AppTheme.primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getNoteFileIcon(_selectedNoteFileName),
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Current: $_selectedNoteFileName',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickNoteFile,
                    icon: const Icon(Icons.upload_file, size: 20),
                    label: Text(
                      widget.user.clientNoteUrl.isNotEmpty
                          ? 'Replace Care Plan'
                          : 'Upload Care Plan',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(
                        color:
                            AppTheme.primaryColor.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceSuggestion {
  final String placeId;
  final String description;
  _PlaceSuggestion({required this.placeId, required this.description});
}
