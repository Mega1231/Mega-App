import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/clock_record.dart';
import '../../services/clock_service.dart';
import '../../theme/app_theme.dart';
import '../admin_web_shell.dart';
import '../web_widgets.dart';

/// Who is clocked in right now, and clock-in history for a chosen range.
class WebClockLogsPage extends StatefulWidget {
  const WebClockLogsPage({super.key});

  @override
  State<WebClockLogsPage> createState() => _WebClockLogsPageState();
}

class _WebClockLogsPageState extends State<WebClockLogsPage> {
  static const _ranges = [7, 14, 30];

  final _service = ClockService();
  List<ClockRecord> _active = [];
  List<ClockRecord> _history = [];
  bool _loadingActive = false;
  bool _loadingHistory = false;
  int _range = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadActive();
    _loadHistory();
  }

  Future<void> _refresh() async {
    await Future.wait([_loadActive(), _loadHistory()]);
  }

  Future<void> _loadActive() async {
    setState(() => _loadingActive = true);
    try {
      _active = await _service.getActiveClockins();
    } catch (_) {}
    if (mounted) setState(() => _loadingActive = false);
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final now = DateTime.now();
      _history = await _service.getRecordsByDateRange(
          now.subtract(Duration(days: _ranges[_range])), now);
    } catch (_) {
      _history = [];
    }
    if (mounted) setState(() => _loadingHistory = false);
  }

  String _hours(double? h) {
    if (h == null) return '—';
    final mins = (h * 60).round();
    return '${mins ~/ 60}h ${(mins % 60).toString().padLeft(2, '0')}m';
  }

  /// Longer than any real shift: almost certainly a missed clock-out.
  bool _stale(ClockRecord r) =>
      DateTime.now().difference(r.clockInTime) > const Duration(hours: 16);

  String _elapsed(DateTime since) {
    final d = DateTime.now().difference(since);
    return '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';
  }

  Widget _mapLink(double lat, double lng) => TextButton.icon(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => launchUrl(
            Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng')),
        icon: const Icon(Icons.place_outlined, size: 16),
        label: const Text('Map', style: TextStyle(fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final history = _history
        .where((r) =>
            q.isEmpty ||
            r.caregiverName.toLowerCase().contains(q) ||
            r.clientName.toLowerCase().contains(q))
        .toList();
    final totalHours =
        history.fold<double>(0, (s, r) => s + (r.totalHours ?? 0));

    return WebPageScaffold(
      onRefresh: _refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebPageHeader(
            title: 'Clock-In Logs',
            subtitle: 'Caregiver attendance with GPS location at clock-in and clock-out',
            actions: [
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Clocked in now',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              WebStatusBadge(
                  label: '${_active.where((r) => !_stale(r)).length} active',
                  color: AppTheme.successColor),
              if (_active.any(_stale)) ...[
                const SizedBox(width: 8),
                WebStatusBadge(
                    label: '${_active.where(_stale).length} not clocked out',
                    color: AppTheme.warningColor),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (_loadingActive)
            const WebCard(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()))
          else if (_active.isEmpty)
            const WebCard(
              padding: EdgeInsets.all(28),
              child: Center(
                child: WebEmptyState(
                    icon: Icons.login_outlined,
                    message: 'Nobody is clocked in right now'),
              ),
            )
          else
            LayoutBuilder(builder: (context, c) {
              final perRow = c.maxWidth >= 1100 ? 3 : 2;
              final w = (c.maxWidth - 16 * (perRow - 1)) / perRow;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final r in _active)
                    SizedBox(
                      width: w,
                      child: WebCard(
                        child: Row(
                          children: [
                            WebAvatar(
                                name: r.caregiverName,
                                photoUrl: r.caregiverPhotoUrl,
                                size: 42),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.caregiverName,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                                  Text('at ${r.clientName}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textSecondary)),
                                  const SizedBox(height: 4),
                                  if (_stale(r))
                                    Text(
                                      'Since ${DateFormat('MMM d, h:mm a').format(r.clockInTime)} · probably forgot to clock out',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.warningColor),
                                    )
                                  else
                                    Text(
                                      'Since ${DateFormat('h:mm a').format(r.clockInTime)} · ${_elapsed(r.clockInTime)}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.successColor),
                                    ),
                                ],
                              ),
                            ),
                            _mapLink(r.clockInLat, r.clockInLng),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            }),
          const SizedBox(height: 32),
          Row(
            children: [
              const Text('History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(width: 16),
              WebFilterTabs(
                labels: [for (final d in _ranges) 'Last $d days'],
                selected: _range,
                onChanged: (i) {
                  setState(() => _range = i);
                  _loadHistory();
                },
              ),
              const SizedBox(width: 16),
              Text(
                '${history.length} records · ${_hours(totalHours)}',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary),
              ),
              const Spacer(),
              WebSearchField(
                hint: 'Search caregiver or client…',
                onChanged: (v) => setState(() => _query = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loadingHistory)
            const WebCard(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()))
          else
            WebTable(
              headers: const [
                'Caregiver',
                'Client',
                'Date',
                'Clock in',
                'Clock out',
                'Hours',
                'Location',
              ],
              flex: const [3, 3, 2, 2, 2, 2, 2],
              empty: const WebEmptyState(
                  icon: Icons.history, message: 'No clock-ins in this period'),
              rows: [
                for (final r in history)
                  [
                    Row(children: [
                      WebAvatar(
                          name: r.caregiverName,
                          photoUrl: r.caregiverPhotoUrl,
                          size: 30),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(r.caregiverName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    Text(r.clientName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                    Text(DateFormat('EEE, MMM d').format(r.clockInTime),
                        style: const TextStyle(fontSize: 13)),
                    Text(DateFormat('h:mm a').format(r.clockInTime),
                        style: const TextStyle(fontSize: 13)),
                    r.clockOutTime == null
                        ? const WebStatusBadge(
                            label: 'Still in', color: AppTheme.successColor)
                        : Text(DateFormat('h:mm a').format(r.clockOutTime!),
                            style: const TextStyle(fontSize: 13)),
                    Text(_hours(r.totalHours),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    _mapLink(r.clockInLat, r.clockInLng),
                  ],
              ],
            ),
        ],
      ),
    );
  }
}
