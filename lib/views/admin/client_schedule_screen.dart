import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_user.dart';
import '../../models/assignment.dart';
import '../../services/assignment_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_snackbar.dart';
import 'assignments_screen.dart';

const _caregiverColor = Color(0xFFE91E63);

/// Month calendar of one client's visits. Tapping a day lets the admin
/// remove (or restore) a single caregiver visit without touching the rest
/// of the recurring assignment.
class ClientScheduleScreen extends StatefulWidget {
  final AppUser client;

  const ClientScheduleScreen({super.key, required this.client});

  @override
  State<ClientScheduleScreen> createState() => _ClientScheduleScreenState();
}

class _ClientScheduleScreenState extends State<ClientScheduleScreen> {
  final AssignmentService _service = AssignmentService();
  late DateTime _month;
  List<Assignment> _assignments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _assignments = await _service.getClientAssignments(widget.client.uid);
    } catch (e) {
      _error = 'Failed to load schedule: $e';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  /// Monday-first weeks covering the visible month.
  List<List<DateTime>> _weeks() {
    final first = DateTime(_month.year, _month.month, 1);
    final last = DateTime(_month.year, _month.month + 1, 0);
    var day = first.subtract(Duration(days: first.weekday - 1));
    final weeks = <List<DateTime>>[];
    while (!day.isAfter(last)) {
      weeks.add(List.generate(7, (i) => DateTime(day.year, day.month, day.day + i)));
      day = DateTime(day.year, day.month, day.day + 7);
    }
    return weeks;
  }

  List<Assignment> _visitsOn(DateTime date) =>
      _assignments.where((a) => a.isScheduledOn(date)).toList()
        ..sort((a, b) => a.caregiverName.compareTo(b.caregiverName));

  List<Assignment> _removedOn(DateTime date) =>
      _assignments.where((a) => a.isExcludedOn(date)).toList();

  static String _shiftLabel(Assignment a) {
    if (a.isLiveIn) return 'Live-in';
    if (a.shiftStartTime.isEmpty) return '';
    return '${a.shiftStartTime} - ${a.shiftEndTime}';
  }

  Future<void> _changeVisit(Assignment a, DateTime date,
      {required bool remove}) async {
    final dayText = DateFormat('EEE, MMM d').format(date);
    if (remove) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove this visit?'),
          content: Text(
              'Remove ${a.caregiverName} from $dayText? Only this day is removed — the rest of the schedule stays.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove',
                  style: TextStyle(color: AppTheme.errorColor)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      if (remove) {
        await _service.excludeDate(a.id, date);
      } else {
        await _service.restoreDate(a.id, date);
      }
      if (!mounted) return;
      CustomSnackbar.success(
        context: context,
        message: remove
            ? '${a.caregiverName} removed from $dayText'
            : '${a.caregiverName} restored on $dayText',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.error(context: context, message: 'Failed to update: $e');
    }
  }

  Future<void> _schedule({DateTime? startDate, bool multiple = false}) async {
    if (multiple) {
      await showGroupAssignmentSheet(
        context,
        client: widget.client,
        startDate: startDate,
      );
    } else {
      await showCreateAssignmentSheet(
        context,
        client: widget.client,
        startDate: startDate,
      );
    }
    if (mounted) await _load();
  }

  void _openDay(DateTime date) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final visits = _visitsOn(date);
        final removed = _removedOn(date);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMM d, yyyy').format(date),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (visits.isEmpty && removed.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No visits scheduled this day',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                for (final a in visits)
                  _DayVisitTile(
                    assignment: a,
                    shift: _shiftLabel(a),
                    actionLabel: 'Remove',
                    actionColor: AppTheme.errorColor,
                    onAction: () {
                      Navigator.pop(ctx);
                      _changeVisit(a, date, remove: true);
                    },
                  ),
                for (final a in removed)
                  _DayVisitTile(
                    assignment: a,
                    shift: 'Removed for this day',
                    removed: true,
                    actionLabel: 'Restore',
                    actionColor: AppTheme.primaryColor,
                    onAction: () {
                      Navigator.pop(ctx);
                      _changeVisit(a, date, remove: false);
                    },
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Schedule from this day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _schedule(startDate: date);
                        },
                        icon: const Icon(Icons.person_add_alt, size: 18),
                        label: const Text('One caregiver'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _schedule(startDate: date, multiple: true);
                        },
                        icon: const Icon(Icons.group_add, size: 18),
                        label: const Text('Multiple'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.client.fullName} – Schedule')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'scheduleMultiple',
            backgroundColor: AppTheme.successColor,
            onPressed: () => _schedule(multiple: true),
            icon: const Icon(Icons.group_add),
            label: const Text('Multiple Caregivers'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'scheduleCaregiver',
            onPressed: () => _schedule(),
            icon: const Icon(Icons.add),
            label: const Text('Schedule Caregiver'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 160),
                    children: [
                      _buildMonthHeader(),
                      const SizedBox(height: 8),
                      _buildGrid(),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Tap a day to remove or restore a caregiver visit for that day only.',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _shiftMonth(-1),
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(_month),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => _shiftMonth(1),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    final today = DateTime.now();
    const border = BorderSide(color: Color(0xFFDDDDDD), width: 0.5);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDDDDDD), width: 0.5),
      ),
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF5F5F5),
            child: Row(
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .map((d) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            d,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          for (final week in _weeks())
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: week.map((date) {
                  final inMonth = date.month == _month.month;
                  final isToday = date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;
                  final visits = _visitsOn(date);
                  final hasRemoved = _removedOn(date).isNotEmpty;

                  return Expanded(
                    child: InkWell(
                      onTap: () => _openDay(date),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 84),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: inMonth ? null : const Color(0xFFFAFAFA),
                          border: const Border(top: border, right: border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: isToday
                                      ? BoxDecoration(
                                          color: AppTheme.primaryColor,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        )
                                      : null,
                                  child: Text(
                                    '${date.day}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isToday
                                          ? Colors.white
                                          : inMonth
                                              ? AppTheme.textPrimary
                                              : AppTheme.textSecondary
                                                  .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                if (hasRemoved) ...[
                                  const Spacer(),
                                  const Icon(Icons.remove_circle,
                                      size: 9, color: AppTheme.errorColor),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            for (final a in visits)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Column(
                                  children: [
                                    Text(
                                      a.caregiverName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: inMonth
                                            ? _caregiverColor
                                            : _caregiverColor
                                                .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    Text(
                                      _shiftLabel(a),
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayVisitTile extends StatelessWidget {
  final Assignment assignment;
  final String shift;
  final bool removed;
  final String actionLabel;
  final Color actionColor;
  final VoidCallback onAction;

  const _DayVisitTile({
    required this.assignment,
    required this.shift,
    this.removed = false,
    required this.actionLabel,
    required this.actionColor,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final name = assignment.caregiverName;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _caregiverColor.withValues(alpha: 0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: _caregiverColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: removed
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                    decoration: removed ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (shift.isNotEmpty)
                  Text(
                    shift,
                    style: TextStyle(
                      fontSize: 12,
                      color: removed
                          ? AppTheme.errorColor
                          : AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: actionColor),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
