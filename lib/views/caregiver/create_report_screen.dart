import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/assignment.dart';
import '../../models/shift_report.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';

/// The report type chosen from the bottom sheet.
enum ReportMode { camera, gallery, manual }

void _showNoClientDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_off_rounded,
                  size: 36, color: AppTheme.warningColor),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Active Client',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'You don\'t have any active client assignments yet. '
              'Please contact your admin to get assigned to a client.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shows the "Create Report" bottom sheet with 3 options,
/// or a "No Active Client" dialog if no assignments exist.
void showCreateReportSheet(
    BuildContext context, List<Assignment> assignments,
    {VoidCallback? onReportCreated}) {
  if (assignments.isEmpty) {
    _showNoClientDialog(context);
    return;
  }

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
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
            const SizedBox(height: 16),
            const Text(
              'Create Shift Report',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose how you want to submit your report',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            _ReportOptionTile(
              icon: Icons.camera_alt,
              color: AppTheme.primaryColor,
              title: 'Take Photo',
              subtitle: 'Capture handwritten notes with camera',
              onTap: () {
                Navigator.pop(ctx);
                _navigateToReport(
                    context, assignments, ReportMode.camera, onReportCreated);
              },
            ),
            const SizedBox(height: 8),
            _ReportOptionTile(
              icon: Icons.photo_library,
              color: AppTheme.successColor,
              title: 'Choose from Gallery',
              subtitle: 'Upload an existing photo',
              onTap: () {
                Navigator.pop(ctx);
                _navigateToReport(
                    context, assignments, ReportMode.gallery, onReportCreated);
              },
            ),
            const SizedBox(height: 8),
            _ReportOptionTile(
              icon: Icons.edit_note,
              color: AppTheme.secondaryColor,
              title: 'Manual Input',
              subtitle: 'Type your shift report details',
              onTap: () {
                Navigator.pop(ctx);
                _navigateToReport(
                    context, assignments, ReportMode.manual, onReportCreated);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _navigateToReport(BuildContext context,
    List<Assignment> assignments, ReportMode mode,
    VoidCallback? onReportCreated) async {
  final result = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          CreateReportScreen(assignments: assignments, mode: mode),
    ),
  );
  if (result == true) {
    onReportCreated?.call();
  }
}

class _ReportOptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportOptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: color.withValues(alpha: 0.05),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: Text(subtitle,
          style:
              const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: color),
      onTap: onTap,
    );
  }
}

// ─── CreateReportScreen ─────────────────────────────────────────────────────

class CreateReportScreen extends StatefulWidget {
  final List<Assignment> assignments;
  final ReportMode mode;

  const CreateReportScreen({
    super.key,
    required this.assignments,
    this.mode = ReportMode.manual,
  });

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  final _notesController = TextEditingController();
  final _conditionController = TextEditingController();
  final _reportService = ReportService();
  final _imagePicker = ImagePicker();

  Assignment? _selectedAssignment;
  DateTime _visitDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);
  bool _isLiveIn = false;
  bool _isSubmitting = false;
  final List<File> _selectedImages = [];

  bool get _isPhotoMode => widget.mode != ReportMode.manual;

  final _activities = {
    'Medication Administration': false,
    'Personal Care': false,
    'Meal Preparation': false,
    'Light Housekeeping': false,
    'Physical Therapy': false,
    'Wound Care': false,
    'Vital Signs Check': false,
    'Companionship': false,
    'Mobility Assistance': false,
    'Health Monitoring': false,
  };

  @override
  void initState() {
    super.initState();
    // Immediately open camera / gallery for photo modes
    if (_isPhotoMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickImage(widget.mode == ReportMode.camera
            ? ImageSource.camera
            : ImageSource.gallery);
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 75,
    );
    if (picked != null) {
      setState(() => _selectedImages.add(File(picked.path)));
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
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
              const Text(
                'Add Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                title: const Text('Take Photo'),
                subtitle: const Text('Use camera to capture report'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
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
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select an existing photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_selectedAssignment == null) {
      _showError('Please select a client');
      return;
    }

    final selectedActivities = _activities.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    // Photo mode: require at least one photo. Manual: require activities or photo.
    if (_isPhotoMode && _selectedImages.isEmpty) {
      _showError('Please add at least one photo');
      return;
    }
    if (!_isPhotoMode &&
        selectedActivities.isEmpty &&
        _selectedImages.isEmpty) {
      _showError('Please select activities or add a photo');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authVm = context.read<AuthViewModel>();
      final currentUser = authVm.currentUser!;
      final String startTimeStr;
      final String endTimeStr;
      if (_isLiveIn) {
        startTimeStr = 'Live-in';
        endTimeStr = '';
      } else {
        startTimeStr = _startTime.format(context);
        endTimeStr = _endTime.format(context);
      }

      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await _reportService.uploadReportImages(
            currentUser.uid, _selectedImages);
      }

      final report = ShiftReport(
        id: '',
        caregiverId: currentUser.uid,
        caregiverName: currentUser.fullName,
        caregiverPhotoUrl: currentUser.photoUrl,
        clientId: _selectedAssignment!.clientId,
        clientName: _selectedAssignment!.clientName,
        clientPhotoUrl: _selectedAssignment!.clientPhotoUrl,
        visitDate: _visitDate,
        startTime: startTimeStr,
        endTime: endTimeStr,
        activitiesPerformed: selectedActivities,
        clientCondition: _conditionController.text.trim(),
        notes: _notesController.text.trim(),
        imageUrls: imageUrls,
      );

      await _reportService.createReport(report);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shift report submitted successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Failed to submit report: $e');
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isPhotoMode ? 'Photo Report' : 'Submit Shift Report'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Client selector — required for all modes
            _buildClientSelector(),
            const SizedBox(height: 16),

            // Visit date
            _buildDatePicker(),
            const SizedBox(height: 16),

            // Live-in toggle
            CheckboxListTile(
              value: _isLiveIn,
              onChanged: (v) => setState(() => _isLiveIn = v ?? false),
              title: const Text(
                'Live-in',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),

            // Time range (hidden when live-in)
            if (!_isLiveIn)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                        );
                        if (t != null) setState(() => _startTime = t);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Time',
                          prefixIcon: Icon(Icons.schedule),
                        ),
                        child: Text(_startTime.format(context)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: _endTime,
                        );
                        if (t != null) setState(() => _endTime = t);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'End Time',
                          prefixIcon: Icon(Icons.schedule),
                        ),
                        child: Text(_endTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // ── Photo section (always shown for photo mode, optional for manual)
            _buildPhotoSection(),
            const SizedBox(height: 24),

            // ── Manual-only: activities checklist
            if (!_isPhotoMode) ...[
              const Text(
                'Activities Performed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (_selectedImages.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Optional when photos are attached',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ),
              const SizedBox(height: 8),
              ..._activities.entries.map(
                (e) => CheckboxListTile(
                  title: Text(e.key, style: const TextStyle(fontSize: 16)),
                  value: e.value,
                  onChanged: (v) => setState(() => _activities[e.key] = v!),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 16),

              // Client condition
              TextField(
                controller: _conditionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Client Condition',
                  alignLabelWithHint: true,
                  hintText: 'How was the client during the visit?',
                  prefixIcon: Icon(Icons.health_and_safety),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Notes (shown in all modes)
            TextField(
              controller: _notesController,
              maxLines: _isPhotoMode ? 3 : 4,
              decoration: InputDecoration(
                labelText:
                    _isPhotoMode ? 'Notes (optional)' : 'Additional Notes',
                alignLabelWithHint: true,
                hintText: _isPhotoMode
                    ? 'Add any notes about this report...'
                    : 'Any other observations or concerns...',
              ),
            ),
            const SizedBox(height: 24),

            // Submit
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReport,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.camera_alt,
                size: 20, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              _isPhotoMode ? 'Report Photos' : 'Photos',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _showImageSourcePicker,
              icon: const Icon(Icons.add_a_photo, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        Text(
          _isPhotoMode
              ? 'Your photo report — add more if needed'
              : 'Take a photo of handwritten notes or upload from gallery',
          style:
              const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (_, i) => _buildImageTile(i),
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _showImageSourcePicker,
            child: Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 32, color: AppTheme.textSecondary),
                  SizedBox(height: 6),
                  Text(
                    'Tap to add photos',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImageTile(int index) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 10),
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            image: DecorationImage(
              image: FileImage(_selectedImages[index]),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 14,
          child: GestureDetector(
            onTap: () => setState(() => _selectedImages.removeAt(index)),
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: AppTheme.errorColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClientSelector() {
    final assignments = widget.assignments;

    return DropdownButtonFormField<Assignment>(
      decoration: const InputDecoration(
        labelText: 'Select Client *',
        prefixIcon: Icon(Icons.person),
      ),
      initialValue: _selectedAssignment,
      items: assignments
          .map((a) => DropdownMenuItem(
                value: a,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          AppTheme.primaryColor.withValues(alpha: 0.1),
                      backgroundImage: a.clientPhotoUrl.isNotEmpty
                          ? NetworkImage(a.clientPhotoUrl)
                          : null,
                      child: a.clientPhotoUrl.isEmpty
                          ? Text(a.clientName[0],
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.primaryColor))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text(a.clientName),
                  ],
                ),
              ))
          .toList(),
      onChanged: (v) => setState(() => _selectedAssignment = v),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _visitDate,
          firstDate: DateTime.now().subtract(const Duration(days: 7)),
          lastDate: DateTime.now(),
        );
        if (date != null) setState(() => _visitDate = date);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Visit Date',
          prefixIcon: Icon(Icons.calendar_today),
        ),
        child: Text(DateFormat('EEEE, MMM d, yyyy').format(_visitDate)),
      ),
    );
  }
}
