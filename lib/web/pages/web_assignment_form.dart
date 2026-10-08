import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_user.dart';
import '../../models/assignment.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/assignment_viewmodel.dart';
import '../web_widgets.dart';

const _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Schedules may be entered up to a year back (to record past visits).
DateTime _earliest() {
  final now = DateTime.now();
  return DateTime(now.year - 1, now.month, now.day);
}

/// Create one or more caregiver schedules for a client, or edit an existing
/// assignment. Resolves to true when something was saved.
Future<bool> showWebAssignmentForm(
  BuildContext context, {
  AppUser? client,
  DateTime? startDate,
  Assignment? assignment,
  DateTime? changeFrom,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _WebAssignmentFormDialog(
      client: client,
      startDate: startDate,
      assignment: assignment,
      changeFrom: changeFrom,
    ),
  );
  return saved == true;
}

class _CaregiverRow {
  AppUser? caregiver;
  bool liveIn = false;
  TimeOfDay? start;
  TimeOfDay? end;
}

class _WebAssignmentFormDialog extends StatefulWidget {
  final AppUser? client;
  final DateTime? startDate;
  final Assignment? assignment;
  final DateTime? changeFrom;

  const _WebAssignmentFormDialog(
      {this.client, this.startDate, this.assignment, this.changeFrom});

  @override
  State<_WebAssignmentFormDialog> createState() =>
      _WebAssignmentFormDialogState();
}

class _WebAssignmentFormDialogState extends State<_WebAssignmentFormDialog> {
  final _vm = AssignmentViewModel();
  AppUser? _client;
  final Set<String> _days = {};
  DateTime? _startDate;
  DateTime? _endDate;
  final List<_CaregiverRow> _rows = [_CaregiverRow()];
  bool _saving = false;
  String? _error;
  late DateTime _changeFrom = DateUtils.dateOnly(widget.changeFrom ?? DateTime.now());

  bool get _isEdit => widget.assignment != null;

  /// Edit mode with a different caregiver picked than the assignment has.
  bool get _caregiverChanged =>
      _isEdit &&
      _rows.first.caregiver != null &&
      _rows.first.caregiver!.uid != widget.assignment!.caregiverId;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    final a = widget.assignment;
    if (a != null) {
      _startDate = a.startDate;
      _endDate = a.endDate;
      final daysPart = a.schedule.split('|').first;
      _days.addAll(_weekDays.where(daysPart.contains));
      final row = _rows.first
        ..liveIn = a.isLiveIn || a.schedule.contains('Live-in')
        ..start = _parseTime(a.shiftStartTime)
        ..end = _parseTime(a.shiftEndTime);
      if (row.liveIn) {
        row.start = null;
        row.end = null;
      }
    }
    _vm.addListener(_onVm);
    _vm.loadDropdownData();
  }

  void _onVm() {
    if (!mounted) return;
    // Resolve preselected people to the dropdown's own instances.
    final clientId = widget.client?.uid ?? widget.assignment?.clientId;
    if (_client == null && clientId != null) {
      _client = _vm.clients.where((c) => c.uid == clientId).firstOrNull;
    }
    final cgId = widget.assignment?.caregiverId;
    if (cgId != null && _rows.first.caregiver == null) {
      _rows.first.caregiver =
          _vm.caregivers.where((c) => c.uid == cgId).firstOrNull;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_onVm);
    _vm.dispose();
    super.dispose();
  }

  static TimeOfDay? _parseTime(String text) {
    final m = RegExp(r'^\s*(\d{1,2}):(\d{2})\s*([AaPp][Mm])\s*$').firstMatch(text);
    if (m == null) return null;
    var h = int.parse(m.group(1)!) % 12;
    if (m.group(3)!.toUpperCase() == 'PM') h += 12;
    return TimeOfDay(hour: h, minute: int.parse(m.group(2)!));
  }

  String _fmtTime(TimeOfDay t) => MaterialLocalizations.of(context)
      .formatTimeOfDay(t, alwaysUse24HourFormat: false);

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final first = start ? _earliest() : (_startDate ?? _earliest());
    final initial = start
        ? (_startDate ?? now)
        : (_endDate ?? _startDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickTime(_CaregiverRow row, {required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (start ? row.start : row.end) ??
          TimeOfDay(hour: start ? 9 : 17, minute: 0),
    );
    if (picked != null) {
      setState(() => start ? row.start = picked : row.end = picked);
    }
  }

  String? _validate() {
    if (_client == null) return 'Choose a client.';
    if (_days.isEmpty) return 'Choose at least one visit day.';
    if (_startDate == null || _endDate == null) {
      return 'Choose a start and end date.';
    }
    final seen = <String>{};
    for (final r in _rows) {
      if (r.caregiver == null) return 'Choose a caregiver for every row.';
      if (!seen.add(r.caregiver!.uid)) {
        return '${r.caregiver!.fullName} is added twice.';
      }
      if (!r.liveIn && (r.start == null || r.end == null)) {
        return 'Set start and end time for ${r.caregiver!.fullName}.';
      }
    }
    return null;
  }

  String _schedule(_CaregiverRow r) {
    final days = _weekDays.where(_days.contains).join(', ');
    final range =
        '${DateFormat('MMM d, yyyy').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}';
    final time =
        r.liveIn ? 'Live-in' : '${_fmtTime(r.start!)} - ${_fmtTime(r.end!)}';
    return '$days | $time | $range';
  }

  Future<void> _save() async {
    final problem = _validate();
    setState(() => _error = problem);
    if (problem != null) return;

    // Warn about overlapping shifts before creating anything.
    if (!_isEdit) {
      final conflicts = <String>[];
      for (final r in _rows.where((r) => !r.liveIn)) {
        final c = await _vm.checkCaregiverAvailability(
          caregiverId: r.caregiver!.uid,
          days: _days,
          startTime: r.start!,
          endTime: r.end!,
        );
        if (c != null) conflicts.add(c);
      }
      if (conflicts.isNotEmpty && mounted) {
        final go = await webConfirm(
          context,
          title: 'Schedule conflict',
          message: '${conflicts.join('\n')}\n\nSave anyway?',
          confirmLabel: 'Save anyway',
        );
        if (!go) return;
      }
    }

    setState(() => _saving = true);
    var failed = 0;
    if (_isEdit) {
      final r = _rows.first;
      final ok = await _vm.updateSchedule(
        widget.assignment!.id,
        _schedule(r),
        shiftStartTime: r.liveIn ? 'Live-in' : _fmtTime(r.start!),
        shiftEndTime: r.liveIn ? '' : _fmtTime(r.end!),
        startDate: _startDate,
        endDate: _endDate,
        isLiveIn: r.liveIn,
      );
      if (ok && _caregiverChanged) {
        final moved = await _vm.changeCaregiver(
            widget.assignment!.id, r.caregiver!, _changeFrom);
        if (!moved) failed++;
      }
      if (!ok) failed++;
    } else {
      for (final r in _rows) {
        final ok = await _vm.createAssignment(
          client: _client!,
          caregiver: r.caregiver!,
          schedule: _schedule(r),
          shiftStartTime: r.liveIn ? 'Live-in' : _fmtTime(r.start!),
          shiftEndTime: r.liveIn ? '' : _fmtTime(r.end!),
          isLiveIn: r.liveIn,
          startDate: _startDate,
          endDate: _endDate,
        );
        if (!ok) failed++;
      }
    }
    if (!mounted) return;
    if (failed > 0) {
      setState(() {
        _saving = false;
        _error = failed == _rows.length
            ? 'Could not save the schedule. Please try again.'
            : '$failed of ${_rows.length} schedules could not be saved.';
      });
      if (failed < _rows.length) Navigator.pop(context, true);
      return;
    }
    webToast(
      context,
      _isEdit
          ? 'Schedule updated'
          : _rows.length == 1
              ? 'Caregiver scheduled'
              : '${_rows.length} caregivers scheduled',
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 820),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit
                          ? 'Edit schedule · ${widget.assignment!.caregiverName}'
                          : 'Schedule caregivers',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed:
                        _saving ? null : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: WebTokens.border),
            Expanded(
              child: _vm.isLoadingDropdowns
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: _body(),
                    ),
            ),
            const Divider(height: 1, color: WebTokens.border),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );

  Widget _body() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Client'),
        DropdownButtonFormField<AppUser>(
          initialValue: _client,
          isExpanded: true,
          decoration: _dec('Choose a client'),
          items: [
            for (final c in _vm.clients)
              DropdownMenuItem(value: c, child: Text(c.fullName)),
          ],
          onChanged: _isEdit ? null : (v) => setState(() => _client = v),
        ),
        const SizedBox(height: 22),
        _label('Visit days'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in _weekDays)
              FilterChip(
                label: Text(d),
                selected: _days.contains(d),
                onSelected: (on) =>
                    setState(() => on ? _days.add(d) : _days.remove(d)),
              ),
            TextButton(
              onPressed: () => setState(() => _days
                ..clear()
                ..addAll(_weekDays)),
              child: const Text('Every day'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: _dateField('Start date', _startDate, true)),
            const SizedBox(width: 14),
            Expanded(child: _dateField('End date', _endDate, false)),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Start dates can go back up to one year.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: _label(_isEdit ? 'Caregiver' : 'Caregivers')),
            if (!_isEdit)
              TextButton.icon(
                onPressed: () => setState(() => _rows.add(_CaregiverRow())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add another caregiver'),
              ),
          ],
        ),
        for (final r in _rows) _caregiverRow(r),
        if (_caregiverChanged) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              SizedBox(
                width: 260,
                child: _dateFieldValue('New caregiver from', _changeFrom, () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _changeFrom,
                    firstDate: _earliest(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _changeFrom = picked);
                }),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '${_rows.first.caregiver!.fullName} takes over from this day. Earlier days stay with ${widget.assignment!.caregiverName}.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _dateFieldValue(String label, DateTime value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: _dec('').copyWith(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(DateFormat('EEE, MMM d, yyyy').format(value),
            style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: WebTokens.border),
        ),
      );

  Widget _dateField(String label, DateTime? value, bool start) {
    return InkWell(
      onTap: () => _pickDate(start: start),
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: _dec('').copyWith(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          value == null ? 'Pick a date' : DateFormat('EEE, MMM d, yyyy').format(value),
          style: TextStyle(
            fontSize: 14,
            color: value == null ? AppTheme.textSecondary : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _timeButton(_CaregiverRow r, bool start) {
    final t = start ? r.start : r.end;
    return OutlinedButton.icon(
      onPressed: r.liveIn ? null : () => _pickTime(r, start: start),
      icon: const Icon(Icons.schedule, size: 16),
      label: Text(t == null ? (start ? 'Start' : 'End') : _fmtTime(t)),
    );
  }

  Widget _caregiverRow(_CaregiverRow r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WebCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<AppUser>(
                initialValue: r.caregiver,
                isExpanded: true,
                decoration: _dec('Choose a caregiver'),
                items: [
                  for (final c in _vm.caregivers)
                    DropdownMenuItem(value: c, child: Text(c.fullName)),
                ],
                onChanged: (v) => setState(() => r.caregiver = v),
              ),
            ),
            const SizedBox(width: 14),
            FilterChip(
              label: const Text('Live-in'),
              selected: r.liveIn,
              onSelected: (on) => setState(() {
                r.liveIn = on;
                if (on) {
                  r.start = null;
                  r.end = null;
                }
              }),
            ),
            const SizedBox(width: 10),
            _timeButton(r, true),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('–'),
            ),
            _timeButton(r, false),
            if (_rows.length > 1)
              IconButton(
                tooltip: 'Remove',
                onPressed: () => setState(() => _rows.remove(r)),
                icon: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _footer() => Padding(
        padding: const EdgeInsets.fromLTRB(28, 14, 28, 14),
        child: Row(
          children: [
            Expanded(
              child: _error == null
                  ? const SizedBox()
                  : Text(_error!,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.errorColor)),
            ),
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
                  : Text(_isEdit ? 'Save changes' : 'Save schedule'),
            ),
          ],
        ),
      );
}
