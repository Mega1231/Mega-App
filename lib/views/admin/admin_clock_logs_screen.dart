import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/clock_record.dart';
import '../../services/clock_service.dart';
import '../../theme/app_theme.dart';

class AdminClockLogsScreen extends StatefulWidget {
  const AdminClockLogsScreen({super.key});

  @override
  State<AdminClockLogsScreen> createState() => _AdminClockLogsScreenState();
}

class _AdminClockLogsScreenState extends State<AdminClockLogsScreen>
    with SingleTickerProviderStateMixin {
  final _clockService = ClockService();
  late TabController _tabController;

  List<ClockRecord> _activeRecords = [];
  List<ClockRecord> _allRecords = [];
  bool _isLoadingActive = true;
  bool _isLoadingAll = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _loadActive();
    _loadAll();
  }

  Future<void> _loadActive() async {
    setState(() => _isLoadingActive = true);
    try {
      _activeRecords = await _clockService.getActiveClockins();
    } catch (_) {}
    if (mounted) setState(() => _isLoadingActive = false);
  }

  Future<void> _loadAll() async {
    setState(() => _isLoadingAll = true);
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      _allRecords = await _clockService.getRecordsByDateRange(weekAgo, now);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingAll = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clock-In Logs'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.successColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.successColor
                              .withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Active (${_activeRecords.length})'),
                ],
              ),
            ),
            const Tab(text: 'Recent History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildActiveTab() {
    if (_isLoadingActive) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activeRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.access_time_rounded,
                  size: 40,
                  color:
                      AppTheme.successColor.withValues(alpha: 0.35)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No caregivers currently clocked in',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Active sessions will appear here',
              style:
                  TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadActive,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _activeRecords.length,
        itemBuilder: (_, i) =>
            _ActiveClockCard(record: _activeRecords[i]),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoadingAll) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allRecords.isEmpty) {
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
              child: Icon(Icons.history_rounded,
                  size: 40,
                  color:
                      AppTheme.primaryColor.withValues(alpha: 0.35)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No clock records',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No records in the past 7 days',
              style:
                  TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allRecords.length,
        itemBuilder: (_, i) =>
            _HistoryClockCard(record: _allRecords[i]),
      ),
    );
  }
}

class _ActiveClockCard extends StatelessWidget {
  final ClockRecord record;
  const _ActiveClockCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(record.clockInTime);
    final hours = elapsed.inHours.toString().padLeft(2, '0');
    final mins = (elapsed.inMinutes % 60).toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.successColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
          // Green accent bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.successColor,
                  AppTheme.successColor.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.successColor
                              .withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.successColor
                            .withValues(alpha: 0.08),
                        backgroundImage:
                            record.caregiverPhotoUrl.isNotEmpty
                                ? NetworkImage(record.caregiverPhotoUrl)
                                : null,
                        child: record.caregiverPhotoUrl.isEmpty
                            ? Text(
                                record.caregiverName.isNotEmpty
                                    ? record.caregiverName[0].toUpperCase()
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.caregiverName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.person_outline_rounded,
                                  size: 13,
                                  color: AppTheme.textSecondary
                                      .withValues(alpha: 0.6)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  record.clientName,
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
                        ],
                      ),
                    ),
                    // Timer
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.successColor
                              .withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: AppTheme.successColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.successColor
                                      .withValues(alpha: 0.4),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$hours:$mins',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              color: AppTheme.successColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Bottom info
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.login_rounded,
                          size: 14,
                          color: AppTheme.textSecondary
                              .withValues(alpha: 0.6)),
                      const SizedBox(width: 6),
                      Text(
                        'Clocked in at ${DateFormat('h:mm a').format(record.clockInTime)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary
                              .withValues(alpha: 0.8),
                        ),
                      ),
                      if (record.clientAddress.isNotEmpty) ...[
                        const Spacer(),
                        Icon(Icons.location_on_outlined,
                            size: 14,
                            color: AppTheme.textSecondary
                                .withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            record.clientAddress,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary
                                  .withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryClockCard extends StatelessWidget {
  final ClockRecord record;
  const _HistoryClockCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final isCompleted = record.status == 'completed';
    final statusColor =
        isCompleted ? AppTheme.successColor : AppTheme.warningColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor:
                  AppTheme.primaryColor.withValues(alpha: 0.06),
              backgroundImage: record.caregiverPhotoUrl.isNotEmpty
                  ? NetworkImage(record.caregiverPhotoUrl)
                  : null,
              child: record.caregiverPhotoUrl.isEmpty
                  ? Text(
                      record.caregiverName.isNotEmpty
                          ? record.caregiverName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.caregiverName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 13,
                        color: AppTheme.textSecondary
                            .withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        record.clientName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule,
                        size: 13,
                        color: AppTheme.textSecondary
                            .withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat('MMM d').format(record.clockInTime)} \u2022 '
                      '${DateFormat('h:mm a').format(record.clockInTime)}'
                      '${record.clockOutTime != null ? ' – ${DateFormat('h:mm a').format(record.clockOutTime!)}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  isCompleted ? 'Completed' : 'Active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              if (record.totalHours != null) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_filled,
                        size: 13,
                        color: AppTheme.textPrimary
                            .withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Text(
                      '${record.totalHours!.toStringAsFixed(1)} hrs',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
