import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/app_user.dart';
import '../../models/assignment.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/caregiver_home_viewmodel.dart';
import '../../widgets/custom_loader.dart';

class CaregiverScheduleScreen extends StatefulWidget {
  final CaregiverHomeViewModel vm;

  const CaregiverScheduleScreen({super.key, required this.vm});

  @override
  State<CaregiverScheduleScreen> createState() =>
      _CaregiverScheduleScreenState();
}

class _CaregiverScheduleScreenState extends State<CaregiverScheduleScreen> {
  late DateTime _selectedDate;
  late List<DateTime> _weekDates;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _weekStart = DateTime(now.year, now.month, now.day);
    _buildWeek();
  }

  late DateTime _weekStart;

  bool get _isOnTodayWeek {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    return !_weekStart.isAfter(todayOnly);
  }

  void _buildWeek() {
    // Build 7 days starting from _weekStart
    _weekDates = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  void _shiftWeek(int direction) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    setState(() {
      final newStart = _weekStart.add(Duration(days: 7 * direction));
      // Don't go before today
      if (newStart.isBefore(todayOnly)) return;
      _weekStart = newStart;
      _selectedDate = _weekStart;
      _buildWeek();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final dayShort = DateFormat('E').format(_selectedDate); // e.g. "Mon"
    final dayAssignments = vm.getAssignmentsForDay(dayShort, date: _selectedDate);

    return Scaffold(
      appBar: AppBar(title: const Text('My Schedule')),
      body: vm.isLoading
          ? const CustomLoader(
              color: AppTheme.primaryColor,
              showMessage: true,
              message: 'Loading schedule...',
            )
          : Column(
              children: [
                // Week navigation
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.chevron_left,
                          color: _isOnTodayWeek
                              ? AppTheme.textSecondary.withValues(alpha: 0.3)
                              : null,
                        ),
                        onPressed: _isOnTodayWeek ? null : () => _shiftWeek(-1),
                      ),
                      Expanded(
                        child: Text(
                          '${DateFormat('MMM d').format(_weekDates.first)} – ${DateFormat('MMM d, yyyy').format(_weekDates.last)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => _shiftWeek(1),
                      ),
                    ],
                  ),
                ),

                // Day chips
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _weekDates.length,
                    itemBuilder: (context, index) {
                      final date = _weekDates[index];
                      final isSelected = _isSameDay(date, _selectedDate);
                      final isToday = _isSameDay(date, DateTime.now());
                      final dayLabel = DateFormat('E').format(date);
                      final hasVisits =
                          vm.getAssignmentsForDay(dayLabel, date: date).isNotEmpty;

                      return GestureDetector(
                        onTap: () => _selectDate(date),
                        child: Container(
                          width: 52,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : isToday
                                      ? AppTheme.primaryColor
                                          .withValues(alpha: 0.4)
                                      : const Color(0xFFE0E0E0),
                              width: isToday && !isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('E').format(date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white70
                                      : AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.textPrimary,
                                ),
                              ),
                              if (hasVisits && !isSelected)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Selected day header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        DateFormat('EEEE, MMM d').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_isSameDay(_selectedDate, DateTime.now()))
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.successColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Today',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.successColor,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        '${dayAssignments.length} visit${dayAssignments.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Visits list
                Expanded(
                  child: dayAssignments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_available,
                                size: 48,
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No visits this day',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'You have no clients scheduled',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: dayAssignments.length,
                          itemBuilder: (context, index) {
                            final a = dayAssignments[index];
                            final client = vm.clientProfiles[a.clientId];
                            return _ScheduleVisitCard(
                              assignment: a,
                              date: _selectedDate,
                              clientProfile: client,
                              index: index,
                              isLast: index == dayAssignments.length - 1,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ScheduleVisitCard extends StatelessWidget {
  final Assignment assignment;
  final DateTime date;
  final AppUser? clientProfile;
  final int index;
  final bool isLast;

  const _ScheduleVisitCard({
    required this.assignment,
    required this.date,
    this.clientProfile,
    required this.index,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final address = clientProfile?.address ?? '';
    final color = index == 0 ? AppTheme.successColor : AppTheme.primaryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: index == 0
                      ? color
                      : color.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 90,
                  color: const Color(0xFFE0E0E0),
                ),
            ],
          ),
          const SizedBox(width: 14),
          // Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: index == 0
                    ? color.withValues(alpha: 0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: index == 0
                      ? color.withValues(alpha: 0.3)
                      : const Color(0xFFE0E0E0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 0.1),
                        backgroundImage:
                            assignment.clientPhotoUrl.isNotEmpty
                                ? NetworkImage(assignment.clientPhotoUrl)
                                : null,
                        child: assignment.clientPhotoUrl.isEmpty
                            ? Text(
                                assignment.clientName.isNotEmpty
                                    ? assignment.clientName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                  fontSize: 14,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          assignment.clientName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (index == 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Next',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.event,
                          size: 14, color: AppTheme.primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        '${DateFormat('EEE, MMM d, yyyy').format(date)}'
                        '${assignment.isLiveIn ? ' · Live-in' : assignment.shiftStartTime.isNotEmpty ? ' · ${assignment.shiftStartTime} - ${assignment.shiftEndTime}' : ''}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 12, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          assignment.schedule,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (clientProfile != null &&
                      clientProfile!.clientNoteUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _openClientNote(
                        context,
                        clientProfile!.clientNoteUrl,
                        clientProfile!.clientNoteFileName,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getNoteIcon(clientProfile!.clientNoteFileName),
                            size: 14,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'View Care Plan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getNoteIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (['jpg', 'jpeg', 'png'].contains(ext)) return Icons.image;
    return Icons.description;
  }

  Future<void> _openClientNote(
      BuildContext context, String url, String fileName) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        await OpenFile.open(file.path);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open file: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}
