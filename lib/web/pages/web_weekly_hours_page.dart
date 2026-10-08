import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/shift_report.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../admin_web_shell.dart';
import '../web_widgets.dart';

/// Hours per caregiver for a Monday–Sunday week, from submitted shift
/// reports. Live-in shifts are counted as shifts but not as hours.
class WebWeeklyHoursPage extends StatefulWidget {
  const WebWeeklyHoursPage({super.key});

  @override
  State<WebWeeklyHoursPage> createState() => _WebWeeklyHoursPageState();
}

class _CaregiverHours {
  final String id;
  final String name;
  final String photoUrl;
  final Map<String, List<ShiftReport>> byClient = {};
  _CaregiverHours(this.id, this.name, this.photoUrl);

  Iterable<ShiftReport> get all => byClient.values.expand((r) => r);
}

class _WebWeeklyHoursPageState extends State<WebWeeklyHoursPage> {
  final _service = ReportService();
  late DateTime _weekStart;
  List<ShiftReport> _reports = [];
  bool _loading = false;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _weekStart = today.subtract(Duration(days: today.weekday - 1));
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _reports = await _service.getReportsForDateRange(
          _weekStart, _weekStart.add(const Duration(days: 7)));
    } catch (e) {
      _reports = [];
      if (mounted) webToast(context, 'Could not load reports: $e', error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _shift(int weeks) {
    setState(() => _weekStart = _weekStart.add(Duration(days: 7 * weeks)));
    _load();
  }

  static bool _isLiveIn(ShiftReport r) => r.timeLabel == 'Live-in';

  static double _hours(ShiftReport r) {
    if (_isLiveIn(r)) return 0;
    int? m(String t) {
      try {
        final d = DateFormat('h:mm a').parse(t.trim());
        return d.hour * 60 + d.minute;
      } catch (_) {
        return null;
      }
    }

    final s = m(r.startTime), e = m(r.endTime);
    if (s == null || e == null || e <= s) return 0;
    return (e - s) / 60;
  }

  String _h(double v) => v == v.roundToDouble() ? '${v.toInt()}h' : '${v.toStringAsFixed(1)}h';

  List<_CaregiverHours> _groups() {
    final map = <String, _CaregiverHours>{};
    for (final r in _reports) {
      final g = map.putIfAbsent(r.caregiverId,
          () => _CaregiverHours(r.caregiverId, r.caregiverName, r.caregiverPhotoUrl));
      g.byClient.putIfAbsent(r.clientName, () => []).add(r);
    }
    final list = map.values.toList()
      ..sort((a, b) => a.all.fold<double>(0, (s, r) => s + _hours(r)).compareTo(
              b.all.fold<double>(0, (s, r) => s + _hours(r))) *
          -1);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups();
    final totalHours = _reports.fold<double>(0, (s, r) => s + _hours(r));
    final liveIns = _reports.where(_isLiveIn).length;
    final end = _weekStart.add(const Duration(days: 6));

    return WebPageScaffold(
      onRefresh: _load,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebPageHeader(
            title: 'Weekly Hours',
            subtitle: 'From submitted shift reports · live-in shifts are listed but not counted as hours',
            actions: [
              IconButton.outlined(
                tooltip: 'Previous week',
                onPressed: () => _shift(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '${DateFormat('MMM d').format(_weekStart)} – ${DateFormat('MMM d, yyyy').format(end)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              IconButton.outlined(
                tooltip: 'Next week',
                onPressed: () => _shift(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 48) / 4;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: w,
                  child: WebStatTile(
                      icon: Icons.schedule,
                      color: AppTheme.primaryColor,
                      value: _loading ? '–' : _h(totalHours),
                      label: 'Hours worked'),
                ),
                SizedBox(
                  width: w,
                  child: WebStatTile(
                      icon: Icons.medical_services_outlined,
                      color: AppTheme.successColor,
                      value: _loading ? '–' : '${groups.length}',
                      label: 'Caregivers'),
                ),
                SizedBox(
                  width: w,
                  child: WebStatTile(
                      icon: Icons.description_outlined,
                      color: const Color(0xFF8E24AA),
                      value: _loading ? '–' : '${_reports.length}',
                      label: 'Shifts reported'),
                ),
                SizedBox(
                  width: w,
                  child: WebStatTile(
                      icon: Icons.home_outlined,
                      color: AppTheme.warningColor,
                      value: _loading ? '–' : '$liveIns',
                      label: 'Live-in shifts'),
                ),
              ],
            );
          }),
          const SizedBox(height: 24),
          if (_loading)
            const WebCard(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (groups.isEmpty)
            const WebCard(
              padding: EdgeInsets.all(48),
              child: Center(
                child: WebEmptyState(
                    icon: Icons.schedule,
                    message: 'No shift reports this week'),
              ),
            )
          else
            WebCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _headerRow(),
                  for (final g in groups) ..._caregiverRows(g),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerRow() {
    Widget h(String t, int f, {TextAlign a = TextAlign.left}) => Expanded(
          flex: f,
          child: Text(t.toUpperCase(),
              textAlign: a,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppTheme.textSecondary)),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFC),
        border: Border(bottom: BorderSide(color: WebTokens.border)),
      ),
      child: Row(children: [
        h('Caregiver', 4),
        h('Clients', 2, a: TextAlign.right),
        h('Shifts', 2, a: TextAlign.right),
        h('Live-in', 2, a: TextAlign.right),
        h('Hours', 2, a: TextAlign.right),
        const SizedBox(width: 40),
      ]),
    );
  }

  List<Widget> _caregiverRows(_CaregiverHours g) {
    final open = _expanded.contains(g.id);
    final shifts = g.all.toList();
    final hours = shifts.fold<double>(0, (s, r) => s + _hours(r));
    TextStyle num = const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
    return [
      InkWell(
        onTap: () => setState(() => open ? _expanded.remove(g.id) : _expanded.add(g.id)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: WebTokens.border)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Row(children: [
                  WebAvatar(name: g.name, photoUrl: g.photoUrl, size: 34),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(g.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
              Expanded(
                  flex: 2,
                  child: Text('${g.byClient.length}',
                      textAlign: TextAlign.right, style: num)),
              Expanded(
                  flex: 2,
                  child: Text('${shifts.length}',
                      textAlign: TextAlign.right, style: num)),
              Expanded(
                  flex: 2,
                  child: Text('${shifts.where(_isLiveIn).length}',
                      textAlign: TextAlign.right, style: num)),
              Expanded(
                flex: 2,
                child: Text(_h(hours),
                    textAlign: TextAlign.right,
                    style: num.copyWith(
                        fontSize: 15, color: AppTheme.primaryColor)),
              ),
              SizedBox(
                width: 40,
                child: Icon(open ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
      if (open)
        Container(
          color: const Color(0xFFFAFBFD),
          padding: const EdgeInsets.fromLTRB(66, 6, 60, 14),
          child: Column(
            children: [
              for (final entry in g.byClient.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Row(children: [
                    Text(entry.key,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(
                        _h(entry.value.fold<double>(0, (s, r) => s + _hours(r))),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
                for (final r in (entry.value
                  ..sort((a, b) => a.visitDate.compareTo(b.visitDate))))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      SizedBox(
                        width: 120,
                        child: Text(DateFormat('EEE, MMM d').format(r.visitDate),
                            style: const TextStyle(fontSize: 13)),
                      ),
                      Expanded(
                        child: Text(r.timeLabel,
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.textSecondary)),
                      ),
                      Text(_isLiveIn(r) ? 'Live-in' : _h(_hours(r)),
                          style: const TextStyle(fontSize: 13)),
                    ]),
                  ),
              ],
            ],
          ),
        ),
    ];
  }
}
