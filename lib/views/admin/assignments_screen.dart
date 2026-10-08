import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../models/assignment.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/assignment_viewmodel.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_loader.dart';
import '../../widgets/custom_snackbar.dart';

const List<String> _weekDays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

class AssignmentsScreen extends StatelessWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AssignmentViewModel()..loadAssignments(),
      child: const _AssignmentsBody(),
    );
  }
}

class _AssignmentsBody extends StatelessWidget {
  const _AssignmentsBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AssignmentViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignments'),
      ),
      body: _buildBody(context, vm),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'addGroupAssignment',
            onPressed: () => _showGroupCreateSheet(context, vm),
            icon: const Icon(Icons.group_add),
            label: const Text('Group Assign'),
            backgroundColor: AppTheme.successColor,
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'addAssignment',
            onPressed: () => _showCreateSheet(context, vm),
            icon: const Icon(Icons.add),
            label: const Text('New Assignment'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AssignmentViewModel vm) {
    if (vm.isLoading && vm.assignments.isEmpty) {
      return const CustomLoader(
        color: AppTheme.primaryColor,
        showMessage: true,
        message: 'Loading assignments...',
      );
    }

    if (vm.assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 40,
                color: AppTheme.primaryColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No assignments yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap the button below to create your first assignment',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scroll) {
        if (scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 200 &&
            !vm.isLoadingMore &&
            vm.hasMore) {
          vm.loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: vm.refresh,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: vm.assignments.length + (vm.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == vm.assignments.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return _AssignmentCard(assignment: vm.assignments[index], vm: vm);
          },
        ),
      ),
    );
  }

  void _showGroupCreateSheet(BuildContext context, AssignmentViewModel vm) {
    vm.loadDropdownData();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: const _GroupAssignmentSheet(),
      ),
    );
  }

  void _showCreateSheet(BuildContext context, AssignmentViewModel vm) {
    vm.loadDropdownData();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: const _CreateAssignmentSheet(),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final AssignmentViewModel vm;

  const _AssignmentCard({required this.assignment, required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // People row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Row(
              children: [
                // Client
                Expanded(
                  child: Column(
                    children: [
                      _PersonAvatar(
                        name: assignment.clientName,
                        photoUrl: assignment.clientPhotoUrl,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        assignment.clientName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Client',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                ),
                // Caregiver
                Expanded(
                  child: Column(
                    children: [
                      _PersonAvatar(
                        name: assignment.caregiverName,
                        photoUrl: assignment.caregiverPhotoUrl,
                        color: AppTheme.successColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        assignment.caregiverName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Caregiver',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.successColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Schedule info
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF0F1F3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.event_note_rounded,
                        size: 15,
                        color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        assignment.schedule,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (assignment.clientAddress.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 15,
                          color: AppTheme.textSecondary
                              .withValues(alpha: 0.6)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          assignment.clientAddress,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (assignment.clientLat != null)
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.gps_fixed,
                              size: 12, color: AppTheme.successColor),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Action buttons
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF0F1F3))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    color: AppTheme.primaryColor,
                    onTap: () => _showEditSheet(context),
                  ),
                ),
                Container(
                    width: 1, height: 40, color: const Color(0xFFF0F1F3)),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.delete_outline,
                    label: 'Remove',
                    color: AppTheme.errorColor,
                    onTap: () => _confirmDelete(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditScheduleSheet(assignment: assignment, vm: vm),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Assignment'),
        content: Text(
          'Remove assignment between ${assignment.clientName} and ${assignment.caregiverName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success = await vm.deleteAssignment(assignment.id);
    if (!context.mounted) return;

    if (success) {
      CustomSnackbar.success(context: context, message: 'Assignment removed.', showFromTop: true);
    } else {
      CustomSnackbar.error(
        context: context,
        message: 'Failed to remove assignment.',
        showFromTop: true,
      );
    }
  }
}

/// Opens the New Assignment form outside the Assignments screen, e.g. from a
/// client's schedule. [client] is preselected and [startDate] prefilled.
Future<void> showCreateAssignmentSheet(
  BuildContext context, {
  AppUser? client,
  DateTime? startDate,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ChangeNotifierProvider(
      create: (_) => AssignmentViewModel()..loadDropdownData(),
      child: _CreateAssignmentSheet(
        initialClientId: client?.uid,
        initialStartDate: startDate,
        refreshListOnCreate: false,
      ),
    ),
  );
}

/// Schedules may be entered up to a year back (e.g. to record past visits).
DateTime _earliestScheduleDate() {
  final now = DateTime.now();
  return DateTime(now.year - 1, now.month, now.day);
}

class _CreateAssignmentSheet extends StatefulWidget {
  final String? initialClientId;
  final DateTime? initialStartDate;
  // The standalone sheet owns a VM that is disposed when the sheet closes.
  final bool refreshListOnCreate;

  const _CreateAssignmentSheet({
    this.initialClientId,
    this.initialStartDate,
    this.refreshListOnCreate = true,
  });

  @override
  State<_CreateAssignmentSheet> createState() => _CreateAssignmentSheetState();
}

class _CreateAssignmentSheetState extends State<_CreateAssignmentSheet> {
  AppUser? _pickedClient;
  AppUser? _selectedCaregiver;
  final Set<String> _selectedDays = {};
  late DateTime? _startDate = widget.initialStartDate;

  // Dropdown items must be the same instances the VM loaded, so the
  // preselected client is resolved by uid once the list is available.
  AppUser? get _selectedClient {
    if (_pickedClient != null || widget.initialClientId == null) {
      return _pickedClient;
    }
    return context
        .read<AssignmentViewModel>()
        .clients
        .where((c) => c.uid == widget.initialClientId)
        .firstOrNull;
  }
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isLiveIn = false;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AssignmentViewModel>();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Assignment',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (vm.isLoadingDropdowns)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              DropdownButtonFormField<AppUser>(
                decoration: InputDecoration(
                  labelText: 'Select Client',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                isExpanded: true,
                initialValue: _selectedClient,
                items: vm.clients
                    .map(
                      (c) =>
                          DropdownMenuItem(value: c, child: Text(c.fullName)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _pickedClient = v),
                hint: Text(
                  vm.clients.isEmpty
                      ? 'No active clients'
                      : 'Choose a client',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AppUser>(
                decoration: InputDecoration(
                  labelText: 'Select Caregiver',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                isExpanded: true,
                initialValue: _selectedCaregiver,
                items: vm.caregivers
                    .map(
                      (c) =>
                          DropdownMenuItem(value: c, child: Text(c.fullName)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedCaregiver = v),
                hint: Text(
                  vm.caregivers.isEmpty
                      ? 'No active caregivers'
                      : 'Choose a caregiver',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Visit Days',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              _DayChipsRow(
                selectedDays: _selectedDays,
                onChanged: (days) => setState(() {
                  _selectedDays.clear();
                  _selectedDays.addAll(days);
                }),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Start Date',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        _DatePickerTile(
                          selectedDate: _startDate,
                          onTap: () => _pickDate(isStart: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('End Date',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        _DatePickerTile(
                          selectedDate: _endDate,
                          onTap: () => _pickDate(isStart: false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _isLiveIn,
                onChanged: (v) => setState(() {
                  _isLiveIn = v ?? false;
                  if (_isLiveIn) {
                    _startTime = null;
                    _endTime = null;
                  }
                }),
                title: const Text(
                  'Live-in Caregiver',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'No specific start/end time required',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (!_isLiveIn) ...[
                const SizedBox(height: 12),
                const Text(
                  'Visit Time',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _TimePickerTile(
                        label: 'Start Time',
                        selectedTime: _startTime,
                        onTap: () => _pickTime(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimePickerTile(
                        label: 'End Time',
                        selectedTime: _endTime,
                        onTap: () => _pickTime(isStart: false),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              CustomButton(
                text: 'Create Assignment',
                isLoading: vm.isCreating,
                onTap: _canSubmit ? () => _submit(vm) : null,
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  bool get _canSubmit =>
      _selectedClient != null &&
      _selectedCaregiver != null &&
      _selectedDays.isNotEmpty &&
      _startDate != null &&
      _endDate != null &&
      (_isLiveIn || (_startTime != null && _endTime != null));

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? now)
          : (_endDate ?? _startDate ?? now),
      firstDate: isStart
          ? _earliestScheduleDate()
          : (_startDate ?? _earliestScheduleDate()),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // Clear end date if it's before start
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart
        ? (_startTime ?? const TimeOfDay(hour: 9, minute: 0))
        : (_endTime ?? const TimeOfDay(hour: 17, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _buildScheduleString() {
    final orderedDays =
        _weekDays.where((d) => _selectedDays.contains(d)).toList();
    final daysPart = orderedDays.join(', ');
    final startDatePart = DateFormat('MMM d, yyyy').format(_startDate!);
    final endDatePart = DateFormat('MMM d, yyyy').format(_endDate!);
    if (_isLiveIn) {
      return '$daysPart | Live-in | $startDatePart - $endDatePart';
    }
    final timePart = '${_startTime!.format(context)} - ${_endTime!.format(context)}';
    return '$daysPart | $timePart | $startDatePart - $endDatePart';
  }

  Future<void> _submit(AssignmentViewModel vm) async {
    final startTimeStr = _isLiveIn ? 'Live-in' : _startTime!.format(context);
    final endTimeStr = _isLiveIn ? '' : _endTime!.format(context);

    final success = await vm.createAssignment(
      client: _selectedClient!,
      caregiver: _selectedCaregiver!,
      schedule: _buildScheduleString(),
      shiftStartTime: startTimeStr,
      shiftEndTime: endTimeStr,
      isLiveIn: _isLiveIn,
      startDate: _startDate,
      endDate: _endDate,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (success) {
      if (widget.refreshListOnCreate) vm.refresh();
      if (!mounted) return;
      CustomSnackbar.success(context: context, message: 'Assignment created.', showFromTop: true);
    } else {
      CustomSnackbar.error(
        context: context,
        message: 'Failed to create assignment.',
        showFromTop: true,
      );
    }
  }
}

/// Opens the Group Assignment form (several caregivers, each with their own
/// time) outside the Assignments screen, with [client] preselected.
Future<void> showGroupAssignmentSheet(
  BuildContext context, {
  AppUser? client,
  DateTime? startDate,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ChangeNotifierProvider(
      create: (_) => AssignmentViewModel()..loadDropdownData(),
      child: _GroupAssignmentSheet(
        initialClientId: client?.uid,
        initialStartDate: startDate,
        refreshListOnCreate: false,
      ),
    ),
  );
}

class _GroupAssignmentSheet extends StatefulWidget {
  final String? initialClientId;
  final DateTime? initialStartDate;
  final bool refreshListOnCreate;

  const _GroupAssignmentSheet({
    this.initialClientId,
    this.initialStartDate,
    this.refreshListOnCreate = true,
  });

  @override
  State<_GroupAssignmentSheet> createState() => _GroupAssignmentSheetState();
}

class _GroupAssignmentSheetState extends State<_GroupAssignmentSheet> {
  AppUser? _pickedClient;
  final Set<String> _selectedCaregiverIds = {};
  final Set<String> _selectedDays = {};
  late DateTime? _startDate = widget.initialStartDate;

  AppUser? get _selectedClient {
    if (_pickedClient != null || widget.initialClientId == null) {
      return _pickedClient;
    }
    return context
        .read<AssignmentViewModel>()
        .clients
        .where((c) => c.uid == widget.initialClientId)
        .firstOrNull;
  }
  DateTime? _endDate;

  // Per-caregiver time slots
  final Map<String, TimeOfDay> _caregiverStartTimes = {};
  final Map<String, TimeOfDay> _caregiverEndTimes = {};

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AssignmentViewModel>();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group_add,
                    color: AppTheme.successColor, size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Group Assignment',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Text(
              'Assign multiple caregivers with individual time slots',
              style: TextStyle(
                  fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            if (vm.isLoadingDropdowns)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              // Client dropdown
              DropdownButtonFormField<AppUser>(
                decoration: InputDecoration(
                  labelText: 'Select Client',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                isExpanded: true,
                initialValue: _selectedClient,
                items: vm.clients
                    .map((c) => DropdownMenuItem(
                        value: c, child: Text(c.fullName)))
                    .toList(),
                onChanged: (v) => setState(() => _pickedClient = v),
                hint: Text(
                  vm.clients.isEmpty
                      ? 'No active clients'
                      : 'Choose a client',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 20),

              // Visit days
              const Text(
                'Visit Days',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              _DayChipsRow(
                selectedDays: _selectedDays,
                onChanged: (days) => setState(() {
                  _selectedDays.clear();
                  _selectedDays.addAll(days);
                }),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Start Date',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        _DatePickerTile(
                          selectedDate: _startDate,
                          onTap: () => _pickGroupDate(isStart: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('End Date',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        _DatePickerTile(
                          selectedDate: _endDate,
                          onTap: () => _pickGroupDate(isStart: false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Caregivers with individual time slots
              const Text(
                'Caregivers & Time Slots',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Set different hours for each caregiver',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              if (vm.caregivers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No active caregivers',
                      style: TextStyle(color: AppTheme.textSecondary)),
                )
              else
                ...vm.caregivers.map((cg) {
                  final selected = _selectedCaregiverIds.contains(cg.uid);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppTheme.successColor.withValues(alpha: 0.5)
                            : Colors.grey.withValues(alpha: 0.2),
                      ),
                      color: selected
                          ? AppTheme.successColor.withValues(alpha: 0.04)
                          : null,
                    ),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: selected,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedCaregiverIds.add(cg.uid);
                              } else {
                                _selectedCaregiverIds.remove(cg.uid);
                                _caregiverStartTimes.remove(cg.uid);
                                _caregiverEndTimes.remove(cg.uid);
                              }
                            });
                          },
                          title: Text(
                            cg.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          secondary: CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                AppTheme.successColor.withValues(alpha: 0.1),
                            backgroundImage: cg.photoUrl.isNotEmpty
                                ? NetworkImage(cg.photoUrl)
                                : null,
                            child: cg.photoUrl.isEmpty
                                ? Text(cg.fullName[0],
                                    style: const TextStyle(
                                        color: AppTheme.successColor,
                                        fontWeight: FontWeight.bold))
                                : null,
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        if (selected)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _TimePickerTile(
                                    label: 'Start Time',
                                    selectedTime: _caregiverStartTimes[cg.uid],
                                    onTap: () =>
                                        _pickCaregiverTime(cg.uid, isStart: true),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _TimePickerTile(
                                    label: 'End Time',
                                    selectedTime: _caregiverEndTimes[cg.uid],
                                    onTap: () =>
                                        _pickCaregiverTime(cg.uid, isStart: false),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              if (_selectedCaregiverIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${_selectedCaregiverIds.length} caregiver${_selectedCaregiverIds.length > 1 ? 's' : ''} selected',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.successColor,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Create ${_selectedCaregiverIds.length} Assignment${_selectedCaregiverIds.length != 1 ? 's' : ''}',
                isLoading: vm.isCreating,
                onTap: _canSubmit ? () => _submit(vm) : null,
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  bool get _canSubmit {
    if (_selectedClient == null ||
        _selectedCaregiverIds.isEmpty ||
        _selectedDays.isEmpty ||
        _startDate == null ||
        _endDate == null) {
      return false;
    }
    // Every selected caregiver must have start and end times
    for (final id in _selectedCaregiverIds) {
      if (_caregiverStartTimes[id] == null ||
          _caregiverEndTimes[id] == null) {
        return false;
      }
    }
    return true;
  }

  Future<void> _pickGroupDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? now)
          : (_endDate ?? _startDate ?? now),
      firstDate: isStart
          ? _earliestScheduleDate()
          : (_startDate ?? _earliestScheduleDate()),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickCaregiverTime(String caregiverId,
      {required bool isStart}) async {
    final initial = isStart
        ? (_caregiverStartTimes[caregiverId] ??
            const TimeOfDay(hour: 9, minute: 0))
        : (_caregiverEndTimes[caregiverId] ??
            const TimeOfDay(hour: 17, minute: 0));
    final picked =
        await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _caregiverStartTimes[caregiverId] = picked;
        } else {
          _caregiverEndTimes[caregiverId] = picked;
        }
      });
    }
  }

  Future<void> _submit(AssignmentViewModel vm) async {
    final orderedDays =
        _weekDays.where((d) => _selectedDays.contains(d)).toList();
    final daysPart = orderedDays.join(', ');
    final startDatePart = DateFormat('MMM d, yyyy').format(_startDate!);
    final endDatePart = DateFormat('MMM d, yyyy').format(_endDate!);

    final selectedCaregivers = vm.caregivers
        .where((c) => _selectedCaregiverIds.contains(c.uid))
        .toList();

    // Build per-caregiver schedule data
    final caregiverSchedules = <AppUser, Map<String, dynamic>>{};
    for (final cg in selectedCaregivers) {
      final startStr = _caregiverStartTimes[cg.uid]!.format(context);
      final endStr = _caregiverEndTimes[cg.uid]!.format(context);
      final timePart = '$startStr - $endStr';
      final schedule = '$daysPart | $timePart | $startDatePart - $endDatePart';
      caregiverSchedules[cg] = {
        'schedule': schedule,
        'startTime': startStr,
        'endTime': endStr,
        'startDate': _startDate!,
        'endDate': _endDate!,
      };
    }

    final success = await vm.createGroupAssignment(
      client: _selectedClient!,
      caregiverSchedules: caregiverSchedules,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (success) {
      if (widget.refreshListOnCreate) vm.refresh();
      if (!mounted) return;
      CustomSnackbar.success(
        context: context,
        message:
            '${selectedCaregivers.length} assignment${selectedCaregivers.length > 1 ? 's' : ''} created.',
        showFromTop: true,
      );
    } else {
      CustomSnackbar.error(
        context: context,
        message: 'Failed to create assignments.',
        showFromTop: true,
      );
    }
  }
}

/// Edit an assignment's days, dates, time and caregiver from anywhere
/// (e.g. a day in the client calendar). [changeFrom] is the first day a new
/// caregiver would take over; it defaults to today.
Future<void> showEditScheduleSheet(
  BuildContext context,
  Assignment assignment, {
  DateTime? changeFrom,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _EditScheduleSheet(
      assignment: assignment,
      vm: AssignmentViewModel(),
      changeFrom: changeFrom,
      ownsVm: true,
    ),
  );
}

class _EditScheduleSheet extends StatefulWidget {
  final Assignment assignment;
  final AssignmentViewModel vm;
  final DateTime? changeFrom;
  // True when the sheet created [vm] itself and must dispose it.
  final bool ownsVm;

  const _EditScheduleSheet({
    required this.assignment,
    required this.vm,
    this.changeFrom,
    this.ownsVm = false,
  });

  @override
  State<_EditScheduleSheet> createState() => _EditScheduleSheetState();
}

class _EditScheduleSheetState extends State<_EditScheduleSheet> {
  late final Set<String> _selectedDays;
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  late bool _isLiveIn;

  AppUser? _newCaregiver;
  late DateTime _changeFrom;

  @override
  void initState() {
    super.initState();
    _parseExistingSchedule();
    final now = DateTime.now();
    _changeFrom = widget.changeFrom ?? DateTime(now.year, now.month, now.day);
    widget.vm.addListener(_onVm);
    if (widget.vm.caregivers.isEmpty) widget.vm.loadDropdownData();
  }

  void _onVm() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.vm.removeListener(_onVm);
    if (widget.ownsVm) widget.vm.dispose();
    super.dispose();
  }

  bool get _caregiverChanged =>
      _newCaregiver != null && _newCaregiver!.uid != widget.assignment.caregiverId;

  void _parseExistingSchedule() {
    final schedule = widget.assignment.schedule;
    _selectedDays = {};
    _isLiveIn = widget.assignment.isLiveIn || schedule.contains('Live-in');

    // Parse days
    for (final day in _weekDays) {
      if (schedule.contains(day)) {
        _selectedDays.add(day);
      }
    }

    // Parse time from "9:00 AM - 5:00 PM" (skip if live-in)
    if (!_isLiveIn) {
      final timeMatch = RegExp(r'(\d{1,2}:\d{2}\s*[APap][Mm])\s*-\s*(\d{1,2}:\d{2}\s*[APap][Mm])').firstMatch(schedule);
      if (timeMatch != null) {
        _startTime = _parseTime(timeMatch.group(1)!);
        _endTime = _parseTime(timeMatch.group(2)!);
      }
    }

    // Parse dates — try new format "Jul 27, 2026 - Aug 27, 2026" first,
    // then legacy "From Jul 27, 2026"
    if (widget.assignment.startDate != null) {
      _startDate = widget.assignment.startDate;
      _endDate = widget.assignment.endDate;
    } else {
      final fromIndex = schedule.indexOf('From ');
      if (fromIndex != -1) {
        try {
          final dateStr = schedule.substring(fromIndex + 5);
          _startDate = DateFormat('MMM d, yyyy').parse(dateStr);
        } catch (_) {
          _startDate = null;
        }
      }
    }
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      final dt = DateFormat('h:mm a').parse(timeStr.trim());
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Schedule',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.assignment.clientName} → ${widget.assignment.caregiverName}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<AppUser>(
              initialValue: widget.vm.caregivers
                  .where((c) => c.uid == (_newCaregiver?.uid ?? widget.assignment.caregiverId))
                  .firstOrNull,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Caregiver',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              hint: Text(widget.vm.isLoadingDropdowns
                  ? 'Loading caregivers…'
                  : widget.assignment.caregiverName),
              items: [
                for (final c in widget.vm.caregivers)
                  DropdownMenuItem(value: c, child: Text(c.fullName)),
              ],
              onChanged: (v) => setState(() => _newCaregiver = v),
            ),
            if (_caregiverChanged) ...[
              const SizedBox(height: 10),
              _DatePickerTile(
                selectedDate: _changeFrom,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _changeFrom,
                    firstDate: _earliestScheduleDate(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _changeFrom = picked);
                },
              ),
              const SizedBox(height: 4),
              Text(
                '${_newCaregiver!.fullName} takes over from this day. Earlier days stay with ${widget.assignment.caregiverName}.',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Visit Days',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _DayChipsRow(
              selectedDays: _selectedDays,
              onChanged: (days) => setState(() {
                _selectedDays.clear();
                _selectedDays.addAll(days);
              }),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Start Date',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      _DatePickerTile(
                        selectedDate: _startDate,
                        onTap: () => _pickEditDate(isStart: true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('End Date',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      _DatePickerTile(
                        selectedDate: _endDate,
                        onTap: () => _pickEditDate(isStart: false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _isLiveIn,
              onChanged: (v) => setState(() {
                _isLiveIn = v ?? false;
                if (_isLiveIn) {
                  _startTime = null;
                  _endTime = null;
                }
              }),
              title: const Text(
                'Live-in Caregiver',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              subtitle: const Text(
                'No specific start/end time required',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (!_isLiveIn) ...[
              const SizedBox(height: 12),
              const Text(
                'Visit Time',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _TimePickerTile(
                      label: 'Start Time',
                      selectedTime: _startTime,
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimePickerTile(
                      label: 'End Time',
                      selectedTime: _endTime,
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            CustomButton(
              text: 'Update Schedule',
              onTap: _canSubmit ? () => _submit() : null,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  bool get _canSubmit =>
      _selectedDays.isNotEmpty &&
      _startDate != null &&
      _endDate != null &&
      (_isLiveIn || (_startTime != null && _endTime != null));

  Future<void> _pickEditDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? now)
          : (_endDate ?? _startDate ?? now),
      firstDate: isStart ? DateTime(2024) : (_startDate ?? DateTime(2024)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart
        ? (_startTime ?? const TimeOfDay(hour: 9, minute: 0))
        : (_endTime ?? const TimeOfDay(hour: 17, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    final orderedDays =
        _weekDays.where((d) => _selectedDays.contains(d)).toList();
    final daysPart = orderedDays.join(', ');
    final startDatePart = DateFormat('MMM d, yyyy').format(_startDate!);
    final endDatePart = DateFormat('MMM d, yyyy').format(_endDate!);
    final String schedule;
    final String startTimeStr;
    final String endTimeStr;
    if (_isLiveIn) {
      schedule = '$daysPart | Live-in | $startDatePart - $endDatePart';
      startTimeStr = 'Live-in';
      endTimeStr = '';
    } else {
      final timePart = '${_startTime!.format(context)} - ${_endTime!.format(context)}';
      schedule = '$daysPart | $timePart | $startDatePart - $endDatePart';
      startTimeStr = _startTime!.format(context);
      endTimeStr = _endTime!.format(context);
    }

    final messenger = Navigator.of(context);
    var success = await widget.vm.updateSchedule(
      widget.assignment.id,
      schedule,
      shiftStartTime: startTimeStr,
      shiftEndTime: endTimeStr,
      startDate: _startDate,
      endDate: _endDate,
      isLiveIn: _isLiveIn,
    );
    // Caregiver change runs after the time/day edit so the new caregiver's
    // copy carries the updated schedule.
    if (success && _caregiverChanged) {
      success = await widget.vm
          .changeCaregiver(widget.assignment.id, _newCaregiver!, _changeFrom);
      if (success && !widget.ownsVm) widget.vm.refresh();
    }
    if (!mounted) return;
    messenger.pop();
    if (success) {
      CustomSnackbar.success(context: context, message: 'Schedule updated.', showFromTop: true);
    } else {
      CustomSnackbar.error(
        context: context,
        message: 'Failed to update schedule.',
        showFromTop: true,
      );
    }
  }
}

class _DayChipsRow extends StatelessWidget {
  final Set<String> selectedDays;
  final ValueChanged<Set<String>> onChanged;

  const _DayChipsRow({required this.selectedDays, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _weekDays.map((day) {
        final isSelected = selectedDays.contains(day);
        return GestureDetector(
          onTap: () {
            final updated = Set<String>.from(selectedDays);
            if (isSelected) {
              updated.remove(day);
            } else {
              updated.add(day);
            }
            onChanged(updated);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              day,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppTheme.primaryColor,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onTap;

  const _DatePickerTile({required this.selectedDate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xffF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedDate != null
                ? AppTheme.primaryColor.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month,
              size: 20,
              color: selectedDate != null
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedDate != null
                    ? DateFormat('MMM d, yyyy').format(selectedDate!)
                    : 'Pick date',
                style: TextStyle(
                  fontSize: 14,
                  color: selectedDate != null
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final String label;
  final TimeOfDay? selectedTime;
  final VoidCallback onTap;

  const _TimePickerTile({
    required this.label,
    required this.selectedTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xffF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedTime != null
                ? AppTheme.primaryColor.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time,
              size: 18,
              color: selectedTime != null
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedTime != null
                        ? selectedTime!.format(context)
                        : 'Select',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: selectedTime != null
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  final String name;
  final String photoUrl;
  final Color color;

  const _PersonAvatar({
    required this.name,
    required this.photoUrl,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2.5),
      ),
      child: CircleAvatar(
        radius: 26,
        backgroundColor: color.withValues(alpha: 0.08),
        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
        child: photoUrl.isEmpty
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              )
            : null,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
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
        ),
      ),
    );
  }
}
