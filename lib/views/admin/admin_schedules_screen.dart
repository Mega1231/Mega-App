import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import '../../models/assignment.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/assignment_viewmodel.dart';
import '../../widgets/custom_loader.dart';

class AdminSchedulesScreen extends StatelessWidget {
  const AdminSchedulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AssignmentViewModel()..loadAssignments(),
      child: const _SchedulesBody(),
    );
  }
}

class _SchedulesBody extends StatefulWidget {
  const _SchedulesBody();

  @override
  State<_SchedulesBody> createState() => _SchedulesBodyState();
}

class _SchedulesBodyState extends State<_SchedulesBody> {
  bool _isDownloading = false;

  Future<void> _downloadSchedulePdf(List<Assignment> assignments) async {
    final period = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Period',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_week),
              title: const Text('Weekly'),
              subtitle: const Text('Last 7 days'),
              onTap: () => Navigator.pop(ctx, 'Weekly'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_month),
              title: const Text('Bi-Weekly'),
              subtitle: const Text('Last 14 days'),
              onTap: () => Navigator.pop(ctx, 'Bi-Weekly'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Monthly'),
              subtitle: const Text('Last 30 days'),
              onTap: () => Navigator.pop(ctx, 'Monthly'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (period == null || !mounted) return;

    setState(() => _isDownloading = true);
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final DateTime startDate;
      switch (period) {
        case 'Bi-Weekly':
          startDate = today.subtract(const Duration(days: 14));
          break;
        case 'Monthly':
          startDate = DateTime(today.year, today.month - 1, today.day);
          break;
        default:
          startDate = today.subtract(const Duration(days: 7));
      }
      final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final activeAssignments =
          assignments.where((a) => a.isActive).toList();

      if (activeAssignments.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No active assignments found.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      final filePath = await PdfService().generateSchedulePdf(
        assignments: activeAssignments,
        startDate: startDate,
        endDate: endDate,
        periodLabel: period,
      );
      await OpenFile.open(filePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AssignmentViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedules'),
        actions: [
          if (vm.assignments.isNotEmpty)
            IconButton(
              onPressed: _isDownloading
                  ? null
                  : () => _downloadSchedulePdf(vm.assignments),
              icon: _isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf, size: 28),
              tooltip: 'Download PDF',
            ),
        ],
      ),
      body: vm.isLoading && vm.assignments.isEmpty
          ? const CustomLoader(
              color: AppTheme.primaryColor,
              showMessage: true,
              message: 'Loading schedules...',
            )
          : vm.assignments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor
                              .withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.calendar_month_outlined,
                          size: 40,
                          color: AppTheme.primaryColor
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No schedules yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Create assignments to see schedules here',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: vm.refresh,
                  child: _ScheduleList(assignments: vm.assignments),
                ),
    );
  }
}

class _ScheduleList extends StatelessWidget {
  final List<Assignment> assignments;

  const _ScheduleList({required this.assignments});

  Map<String, List<Assignment>> _groupByDay() {
    final now = DateTime.now();
    final todayShort = DateFormat('E').format(now);
    final tomorrowShort =
        DateFormat('E').format(now.add(const Duration(days: 1)));

    final dayOrder = <String>[];
    for (int i = 0; i < 7; i++) {
      dayOrder.add(DateFormat('E').format(now.add(Duration(days: i))));
    }

    final grouped = <String, List<Assignment>>{};
    for (final day in dayOrder) {
      final matches =
          assignments.where((a) => a.schedule.contains(day)).toList();
      if (matches.isNotEmpty) {
        String label;
        if (day == todayShort) {
          label = 'Today – ${DateFormat('EEEE, MMM d').format(now)}';
        } else if (day == tomorrowShort) {
          final tomorrow = now.add(const Duration(days: 1));
          label =
              'Tomorrow – ${DateFormat('EEEE, MMM d').format(tomorrow)}';
        } else {
          final date = now.add(Duration(days: dayOrder.indexOf(day)));
          label = DateFormat('EEEE, MMM d').format(date);
        }
        grouped[label] = matches;
      }
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDay();

    if (grouped.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available,
                size: 36,
                color: AppTheme.primaryColor.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No upcoming schedules',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in grouped.entries) ...[
          _DayHeader(text: entry.key),
          _DaySection(assignments: entry.value),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _DaySection extends StatefulWidget {
  final List<Assignment> assignments;
  const _DaySection({required this.assignments});

  @override
  State<_DaySection> createState() => _DaySectionState();
}

class _DaySectionState extends State<_DaySection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _rotationAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.assignments.length - 1;

    return Column(
      children: [
        // Always show first card
        _ScheduleCard(assignment: widget.assignments.first),

        // Expandable remaining cards
        if (remaining > 0) ...[
          SizeTransition(
            sizeFactor: _expandAnimation,
            axisAlignment: -1.0,
            child: Column(
              children: widget.assignments
                  .skip(1)
                  .map((a) => _ScheduleCard(assignment: a))
                  .toList(),
            ),
          ),

          // View all / Collapse button
          GestureDetector(
            onTap: _toggle,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isExpanded
                        ? 'Show less'
                        : 'View all $remaining more schedule${remaining > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 6),
                  RotationTransition(
                    turns: _rotationAnimation,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: AppTheme.primaryColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String text;
  const _DayHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    final isToday = text.startsWith('Today');

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 14),
      child: Row(
        children: [
          if (isToday)
            Container(
              width: 4,
              height: 20,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isToday
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
              ),
            ),
          ),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Today',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.successColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final Assignment assignment;

  const _ScheduleCard({required this.assignment});

  String _extractTime() {
    final match = RegExp(
            r'(\d{1,2}:\d{2}\s*[APap][Mm])\s*-\s*(\d{1,2}:\d{2}\s*[APap][Mm])')
        .firstMatch(assignment.schedule);
    if (match != null) return match.group(0)!;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final time = _extractTime();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Caregiver avatar
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.successColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor:
                  AppTheme.successColor.withValues(alpha: 0.08),
              backgroundImage: assignment.caregiverPhotoUrl.isNotEmpty
                  ? NetworkImage(assignment.caregiverPhotoUrl)
                  : null,
              child: assignment.caregiverPhotoUrl.isEmpty
                  ? Text(
                      assignment.caregiverName.isNotEmpty
                          ? assignment.caregiverName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successColor,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment.caregiverName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 14,
                        color: AppTheme.textSecondary
                            .withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        assignment.clientName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.schedule,
                          size: 14,
                          color: AppTheme.primaryColor
                              .withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Client avatar
          Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.25),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor:
                  AppTheme.primaryColor.withValues(alpha: 0.06),
              backgroundImage: assignment.clientPhotoUrl.isNotEmpty
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
                        fontSize: 13,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
