import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/shift_report.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_loader.dart';

class WeeklyHoursScreen extends StatefulWidget {
  const WeeklyHoursScreen({super.key});

  @override
  State<WeeklyHoursScreen> createState() => _WeeklyHoursScreenState();
}

class _WeeklyHoursScreenState extends State<WeeklyHoursScreen> {
  final ReportService _reportService = ReportService();
  late DateTime _weekStart;
  bool _isLoading = false;
  List<ShiftReport> _reports = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
    _loadReports();
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 7));

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      _reports = await _reportService.getReportsForDateRange(
        _weekStart,
        _weekEnd,
      );
    } catch (_) {
      _reports = [];
    }
    setState(() => _isLoading = false);
  }

  void _shiftWeek(int direction) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * direction));
    });
    _loadReports();
  }

  int _parseTimeToMinutes(String time) {
    try {
      final dt = DateFormat('h:mm a').parse(time.trim());
      return dt.hour * 60 + dt.minute;
    } catch (_) {
      return 0;
    }
  }

  double _calcHours(String startTime, String endTime) {
    if (startTime.startsWith('Live-in')) return 0;
    final startMin = _parseTimeToMinutes(startTime);
    final endMin = _parseTimeToMinutes(endTime);
    if (endMin <= startMin) return 0;
    return (endMin - startMin) / 60.0;
  }

  Map<String, _CaregiverGroup> _buildGroups() {
    final groups = <String, _CaregiverGroup>{};
    for (final report in _reports) {
      final cgKey = report.caregiverId;
      groups.putIfAbsent(
        cgKey,
        () => _CaregiverGroup(
          caregiverName: report.caregiverName,
          caregiverPhotoUrl: report.caregiverPhotoUrl,
        ),
      );
      final clientKey = report.clientId;
      groups[cgKey]!.clients.putIfAbsent(
        clientKey,
        () => _ClientGroup(
          clientName: report.clientName,
          clientPhotoUrl: report.clientPhotoUrl,
        ),
      );
      groups[cgKey]!.clients[clientKey]!.reports.add(report);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _buildGroups();
    final weekStart = _weekStart;
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final isSameMonth = weekStart.month == weekEnd.month;
    final weekLabel = isSameMonth
        ? '${DateFormat('MMM d').format(weekStart)} – ${DateFormat('d, yyyy').format(weekEnd)}'
        : '${DateFormat('MMM d').format(weekStart)} – ${DateFormat('MMM d, yyyy').format(weekEnd)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Hours')),
      body: Column(
        children: [
          // Week navigation
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Material(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _shiftWeek(-1),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.chevron_left,
                            color: AppTheme.primaryColor, size: 22),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          weekLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Week ${_weekNumber(weekStart)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _shiftWeek(1),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.chevron_right,
                            color: AppTheme.primaryColor, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const CustomLoader(
                    color: AppTheme.primaryColor,
                    showMessage: true,
                    message: 'Loading reports...',
                  )
                : groups.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final cgId = groups.keys.elementAt(index);
                          final group = groups[cgId]!;
                          return _CaregiverCard(
                            group: group,
                            calcHours: _calcHours,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  int _weekNumber(DateTime date) {
    final jan1 = DateTime(date.year, 1, 1);
    final diff = date.difference(jan1).inDays;
    return ((diff + jan1.weekday) / 7).ceil();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.timer_off_outlined,
              size: 40,
              color: AppTheme.primaryColor.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No shift reports this week',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Reports will appear once\ncaregivers submit them',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data models ──────────────────────────────────────────────

class _CaregiverGroup {
  final String caregiverName;
  final String caregiverPhotoUrl;
  final Map<String, _ClientGroup> clients = {};
  _CaregiverGroup(
      {required this.caregiverName, required this.caregiverPhotoUrl});
}

class _ClientGroup {
  final String clientName;
  final String clientPhotoUrl;
  final List<ShiftReport> reports = [];
  _ClientGroup({required this.clientName, required this.clientPhotoUrl});
}

// ── Caregiver Card ───────────────────────────────────────────

class _CaregiverCard extends StatefulWidget {
  final _CaregiverGroup group;
  final double Function(String, String) calcHours;

  const _CaregiverCard({required this.group, required this.calcHours});

  @override
  State<_CaregiverCard> createState() => _CaregiverCardState();
}

class _CaregiverCardState extends State<_CaregiverCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _animController;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final calcHours = widget.calcHours;

    double totalCaregiverHours = 0;
    int totalShifts = 0;
    for (final cl in group.clients.values) {
      for (final r in cl.reports) {
        totalCaregiverHours += calcHours(r.startTime, r.endTime);
      }
      totalShifts += cl.reports.length;
    }

    final clientList = group.clients.values.toList();
    final hasMultipleClients = clientList.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Caregiver header ──
          Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.85),
                  AppTheme.secondaryColor,
                ],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Avatar with ring
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2.5,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.15),
                        backgroundImage:
                            group.caregiverPhotoUrl.isNotEmpty
                                ? NetworkImage(group.caregiverPhotoUrl)
                                : null,
                        child: group.caregiverPhotoUrl.isEmpty
                            ? Text(
                                group.caregiverName.isNotEmpty
                                    ? group.caregiverName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 20,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.caregiverName,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Caregiver',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white
                                    .withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Stats row
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _HeaderStat(
                        icon: Icons.schedule,
                        value: totalCaregiverHours.toStringAsFixed(1),
                        label: 'Hours',
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      _HeaderStat(
                        icon: Icons.people_outline,
                        value: '${group.clients.length}',
                        label: group.clients.length == 1
                            ? 'Client'
                            : 'Clients',
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      _HeaderStat(
                        icon: Icons.description_outlined,
                        value: '$totalShifts',
                        label: totalShifts == 1 ? 'Shift' : 'Shifts',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── First client always visible ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: _ClientSection(
                clientGroup: clientList.first, calcHours: calcHours),
          ),

          // ── Remaining clients animated ──
          if (hasMultipleClients) ...[
            SizeTransition(
              sizeFactor: _expandAnimation,
              axisAlignment: -1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: clientList
                      .skip(1)
                      .map((cl) => _ClientSection(
                          clientGroup: cl, calcHours: calcHours))
                      .toList(),
                ),
              ),
            ),

            // Expand / collapse button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggle,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFF0F1F3)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _expanded
                            ? 'Show less'
                            : 'View all ${clientList.length} clients',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      RotationTransition(
                        turns: _rotationAnimation,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          if (!hasMultipleClients) const SizedBox(height: 14),
        ],
      ),
    );
  }
}

// ── Header stat widget ───────────────────────────────────────

class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _HeaderStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Client section ───────────────────────────────────────────

class _ClientSection extends StatelessWidget {
  final _ClientGroup clientGroup;
  final double Function(String, String) calcHours;

  const _ClientSection({
    required this.clientGroup,
    required this.calcHours,
  });

  @override
  Widget build(BuildContext context) {
    double clientHours = 0;
    for (final r in clientGroup.reports) {
      clientHours += calcHours(r.startTime, r.endTime);
    }

    final sorted = List<ShiftReport>.from(clientGroup.reports)
      ..sort((a, b) => a.visitDate.compareTo(b.visitDate));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEFF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Client header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      AppTheme.warningColor.withValues(alpha: 0.1),
                  backgroundImage: clientGroup.clientPhotoUrl.isNotEmpty
                      ? NetworkImage(clientGroup.clientPhotoUrl)
                      : null,
                  child: clientGroup.clientPhotoUrl.isEmpty
                      ? Text(
                          clientGroup.clientName.isNotEmpty
                              ? clientGroup.clientName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.warningColor,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientGroup.clientName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${sorted.length} shift${sorted.length == 1 ? '' : 's'} this week',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_filled,
                          size: 13, color: AppTheme.successColor),
                      const SizedBox(width: 4),
                      Text(
                        '${clientHours.toStringAsFixed(1)} hrs',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Shift rows
          ...sorted.asMap().entries.map((entry) {
            final r = entry.value;
            final isLast = entry.key == sorted.length - 1;
            final hours = calcHours(r.startTime, r.endTime);
            final dayName = DateFormat('EEE, MMM d').format(r.visitDate);
            return Container(
              margin: EdgeInsets.fromLTRB(10, 0, 10, isLast ? 10 : 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFF0F1F3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_note_rounded,
                      size: 14,
                      color:
                          AppTheme.primaryColor.withValues(alpha: 0.5)),
                  const SizedBox(width: 8),
                  Text(
                    dayName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    r.timeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary
                          .withValues(alpha: 0.8),
                    ),
                  ),
                  if (!r.isLiveIn) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${hours.toStringAsFixed(1)}h',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
