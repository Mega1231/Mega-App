import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_user.dart';
import '../../models/assignment.dart';
import '../../services/assignment_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/assignment_viewmodel.dart';
import '../web_widgets.dart';
import 'web_assignment_form.dart';

const _palette = [
  Color(0xFFD81B60),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFF4511E),
  Color(0xFF8E24AA),
  Color(0xFF00897B),
  Color(0xFF6D4C41),
  Color(0xFF3949AB),
];

/// Stable color per caregiver so the same person reads the same everywhere.
Color caregiverColor(String caregiverId) =>
    _palette[caregiverId.codeUnits.fold(0, (a, b) => a + b) % _palette.length];

String shiftLabel(Assignment a) {
  if (a.isLiveIn || a.shiftStartTime == 'Live-in') return 'Live-in';
  if (a.shiftStartTime.isEmpty) return '';
  return '${a.shiftStartTime} – ${a.shiftEndTime}';
}

/// Per-client month calendar: pick a client on the left, see every
/// caregiver visit per day, remove or restore single days, and schedule.
class WebSchedulesPage extends StatefulWidget {
  const WebSchedulesPage({super.key});

  @override
  State<WebSchedulesPage> createState() => _WebSchedulesPageState();
}

class _WebSchedulesPageState extends State<WebSchedulesPage> {
  final _vm = AssignmentViewModel();
  final _service = AssignmentService();
  AppUser? _client;
  String _query = '';
  late DateTime _month;
  List<Assignment> _assignments = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _vm.addListener(_onVm);
    _vm.loadDropdownData();
  }

  void _onVm() {
    if (!mounted) return;
    if (_client == null && _people.isNotEmpty) {
      _select(_people.first);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onVm);
    _vm.dispose();
    super.dispose();
  }

  Future<void> _select(AppUser client) async {
    setState(() {
      _client = client;
      _loading = true;
    });
    await _reload();
  }

  Future<void> _reload() async {
    final client = _client;
    if (client == null) return;
    try {
      final list = _byCaregiver
          ? await _service.getCaregiverAssignments(client.uid)
          : await _service.getClientAssignments(client.uid);
      if (mounted && _client?.uid == client.uid) {
        setState(() => _assignments = list);
      }
    } catch (e) {
      if (mounted) webToast(context, 'Could not load schedule: $e', error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Assignment> _visitsOn(DateTime d) =>
      _assignments.where((a) => a.isScheduledOn(d)).toList()
        ..sort((a, b) => _label(a).compareTo(_label(b)));

  /// The caregiver on a client's calendar, the client on a caregiver's.
  String _label(Assignment a) => _byCaregiver ? a.clientName : a.caregiverName;

  /// Color by the other side of the visit, so each person stays one color.
  Color _color(Assignment a) =>
      caregiverColor(_byCaregiver ? a.clientId : a.caregiverId);

  List<Assignment> _removedOn(DateTime d) =>
      _assignments.where((a) => a.isExcludedOn(d)).toList();

  List<List<DateTime>> _weeks() {
    final first = DateTime(_month.year, _month.month, 1);
    final last = DateTime(_month.year, _month.month + 1, 0);
    var day = first.subtract(Duration(days: first.weekday - 1));
    final weeks = <List<DateTime>>[];
    while (!day.isAfter(last)) {
      weeks.add(
          List.generate(7, (i) => DateTime(day.year, day.month, day.day + i)));
      day = DateTime(day.year, day.month, day.day + 7);
    }
    return weeks;
  }

  Future<void> _downloadPdf() async {
    try {
      await PdfService().generateClientSchedulePdf(
        clientName: _client!.fullName,
        assignments: _assignments,
      );
    } catch (e) {
      if (mounted) webToast(context, 'Could not create PDF: $e', error: true);
    }
  }

  Future<void> _schedule({DateTime? from}) async {
    final saved =
        await showWebAssignmentForm(context,
            client: _byCaregiver ? null : _client, startDate: from);
    if (saved) await _reload();
  }

  int _mode = 0; // 0 by client, 1 by caregiver, 2 week overview
  bool get _byCaregiver => _mode == 1;
  List<AppUser> get _people => _byCaregiver ? _vm.caregivers : _vm.clients;

  void _setMode(int mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _client = null;
      _assignments = [];
    });
    if (mode != 2 && _people.isNotEmpty) _select(_people.first);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: WebTokens.border)),
          ),
          child: Row(
            children: [
              WebFilterTabs(
                labels: const ['By client', 'By caregiver', 'Week overview'],
                selected: _mode,
                onChanged: _setMode,
              ),
            ],
          ),
        ),
        Expanded(
          child: _mode == 2
              ? const _WeekOverview()
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _clientList(),
                    const VerticalDivider(width: 1, color: WebTokens.border),
                    Expanded(child: _calendarPane()),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _clientList() {
    final q = _query.trim().toLowerCase();
    final clients = _people
        .where((c) => q.isEmpty || c.fullName.toLowerCase().contains(q))
        .toList();
    return Container(
      width: 280,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
            child: Text(_byCaregiver ? 'Caregivers' : 'Clients',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(_byCaregiver ? 'Active caregivers only' : 'Active clients only',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: _byCaregiver ? 'Search caregivers' : 'Search clients',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: WebTokens.border),
                ),
              ),
            ),
          ),
          Expanded(
            child: _vm.isLoadingDropdowns
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: [
                      for (final c in clients)
                        Material(
                          color: c.uid == _client?.uid
                              ? AppTheme.primaryColor.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            leading: WebAvatar(
                                name: c.fullName, photoUrl: c.photoUrl, size: 32),
                            title: Text(
                              c.fullName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: c.uid == _client?.uid
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              c.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () => _select(c),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _calendarPane() {
    if (_client == null) {
      return Center(
        child: _vm.isLoadingDropdowns
            ? const CircularProgressIndicator()
            : const WebEmptyState(
                icon: Icons.calendar_month_outlined,
                message: 'Choose someone to see their schedule'),
      );
    }
    final caregivers = <String, Assignment>{
      for (final a in _assignments) a.caregiverId: a,
    }.values.toList();

    return SingleChildScrollView(
      padding: WebTokens.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebPageHeader(
            title: _client!.fullName,
            subtitle: _byCaregiver
                ? 'Caregiver · visits across all clients'
                : _client!.address,
            actions: [
              if (!_byCaregiver)
              OutlinedButton.icon(
                onPressed: _assignments.isEmpty ? null : _downloadPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Download PDF'),
              ),
              FilledButton.icon(
                onPressed: () => _schedule(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Schedule caregivers'),
              ),
            ],
          ),
          WebCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _monthBar(),
                const Divider(height: 1, color: WebTokens.border),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  _grid(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Click a day to remove or restore a visit for that day only, or to schedule from that day.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          if (caregivers.isNotEmpty) ...[
            const SizedBox(height: 24),
            _assignmentList(),
          ],
        ],
      ),
    );
  }

  Widget _monthBar() {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1)),
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 8),
          Text(
            DateFormat('MMMM yyyy').format(_month),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: () =>
                setState(() => _month = DateTime(now.year, now.month)),
            child: const Text('Today'),
          ),
        ],
      ),
    );
  }

  Widget _grid() {
    final today = DateTime.now();
    const border = BorderSide(color: WebTokens.border);
    return Column(
      children: [
        Container(
          color: const Color(0xFFF9FAFC),
          child: Row(
            children: [
              for (final d in const [
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday',
                'Saturday',
                'Sunday'
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (final week in _weeks())
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < 7; i++)
                  Expanded(
                    child: _DayCell(
                      date: week[i],
                      inMonth: week[i].month == _month.month,
                      isToday: DateUtils.isSameDay(week[i], today),
                      visits: _visitsOn(week[i]),
                      label: _label,
                      color: _color,
                      hasRemoved: _removedOn(week[i]).isNotEmpty,
                      border: Border(
                        top: border,
                        right: i < 6 ? border : BorderSide.none,
                      ),
                      onTap: () => _openDay(week[i]),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _assignmentList() {
    return WebTable(
      headers: [_byCaregiver ? 'Client' : 'Caregiver', 'Days', 'Shift', 'Dates', ''],
      flex: const [3, 4, 2, 3, 1],
      rows: [
        for (final a in _assignments)
          [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _color(a),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(_label(a),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            Text(a.schedule.split('|').first.trim(),
                style: const TextStyle(fontSize: 13)),
            Text(shiftLabel(a), style: const TextStyle(fontSize: 13)),
            Text(
              a.startDate == null
                  ? '—'
                  : '${DateFormat('MMM d, yyyy').format(a.startDate!)} – ${a.endDate == null ? '…' : DateFormat('MMM d, yyyy').format(a.endDate!)}',
              style: const TextStyle(fontSize: 13),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz,
                    color: AppTheme.textSecondary),
                onSelected: (v) => v == 'edit' ? _edit(a) : _delete(a),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit schedule')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Remove assignment',
                        style: TextStyle(color: AppTheme.errorColor)),
                  ),
                ],
              ),
            ),
          ],
      ],
    );
  }

  Future<void> _edit(Assignment a) async {
    final saved = await showWebAssignmentForm(context, assignment: a);
    if (saved) await _reload();
  }

  Future<void> _delete(Assignment a) async {
    final ok = await webConfirm(
      context,
      title: 'Remove ${a.caregiverName} from ${a.clientName}?',
      message:
          'This deletes the whole recurring assignment. To skip a single day, click that day in the calendar instead.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _service.deleteAssignment(a.id);
      if (mounted) webToast(context, 'Assignment removed');
      await _reload();
    } catch (e) {
      if (mounted) webToast(context, 'Could not remove: $e', error: true);
    }
  }

  Future<void> _changeDay(Assignment a, DateTime d, {required bool remove}) async {
    final day = DateFormat('EEE, MMM d').format(d);
    if (remove) {
      final ok = await webConfirm(
        context,
        title: 'Remove this visit?',
        message:
            'Remove ${a.caregiverName} from $day? Only this day is removed — the rest of the schedule stays.',
        confirmLabel: 'Remove',
        destructive: true,
      );
      if (!ok) return;
    }
    try {
      remove
          ? await _service.excludeDate(a.id, d)
          : await _service.restoreDate(a.id, d);
      if (mounted) {
        webToast(context,
            '${a.caregiverName} ${remove ? 'removed from' : 'restored on'} $day');
      }
      await _reload();
    } catch (e) {
      if (mounted) webToast(context, 'Could not update: $e', error: true);
    }
  }

  void _openDay(DateTime d) {
    final visits = _visitsOn(d);
    final removed = _removedOn(d);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(DateFormat('EEEE, MMMM d, yyyy').format(d)),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (visits.isEmpty && removed.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No visits scheduled this day.',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
              for (final a in visits)
                _dayRow(a, shiftLabel(a), 'Remove', AppTheme.errorColor, () {
                  Navigator.pop(ctx);
                  _changeDay(a, d, remove: true);
                }, onEdit: () async {
                  Navigator.pop(ctx);
                  final saved = await showWebAssignmentForm(context,
                      assignment: a, changeFrom: d);
                  if (saved) await _reload();
                }),
              for (final a in removed)
                _dayRow(a, 'Removed for this day', 'Restore',
                    AppTheme.primaryColor, () {
                  Navigator.pop(ctx);
                  _changeDay(a, d, remove: false);
                }, struck: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _schedule(from: d);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Schedule from this day'),
          ),
        ],
      ),
    );
  }

  Widget _dayRow(Assignment a, String sub, String action, Color color,
      VoidCallback onTap,
      {bool struck = false, VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: struck
                  ? AppTheme.textSecondary.withValues(alpha: 0.3)
                  : _color(a),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label(a),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: struck ? TextDecoration.lineThrough : null,
                    color: struck ? AppTheme.textSecondary : AppTheme.textPrimary,
                  ),
                ),
                Text(sub,
                    style: TextStyle(
                      fontSize: 12,
                      color: struck ? AppTheme.errorColor : AppTheme.textSecondary,
                    )),
              ],
            ),
          ),
          if (onEdit != null)
            TextButton(onPressed: onEdit, child: const Text('Edit')),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(foregroundColor: color),
            child: Text(action),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatefulWidget {
  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final List<Assignment> visits;
  final String Function(Assignment) label;
  final Color Function(Assignment) color;
  final bool hasRemoved;
  final Border border;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.visits,
    required this.label,
    required this.color,
    required this.hasRemoved,
    required this.border,
    required this.onTap,
  });

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 118),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hover
                ? WebTokens.rowHover
                : widget.inMonth
                    ? Colors.white
                    : const Color(0xFFFAFBFC),
            border: widget.border,
          ),
          child: Opacity(
            opacity: widget.inMonth ? 1 : 0.45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: widget.isToday
                          ? BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(10),
                            )
                          : null,
                      child: Text(
                        '${widget.date.day}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: widget.isToday
                              ? Colors.white
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (widget.hasRemoved)
                      const Tooltip(
                        message: 'A visit was removed this day',
                        child: Icon(Icons.remove_circle,
                            size: 14, color: AppTheme.errorColor),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final a in widget.visits)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.color(a)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border(
                        left: BorderSide(
                            color: widget.color(a), width: 3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label(a),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: widget.color(a),
                          ),
                        ),
                        Text(
                          shiftLabel(a),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Every client's visits for one Monday–Sunday week: clients as rows,
/// days as columns.
class _WeekOverview extends StatefulWidget {
  const _WeekOverview();

  @override
  State<_WeekOverview> createState() => _WeekOverviewState();
}

class _WeekOverviewState extends State<_WeekOverview> {
  final _vm = AssignmentViewModel();
  late DateTime _weekStart;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _weekStart = today.subtract(Duration(days: today.weekday - 1));
    _vm.addListener(_rebuild);
    _loadAll();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_rebuild);
    _vm.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _vm.loadAssignments();
    while (mounted && _vm.hasMore) {
      final before = _vm.assignments.length;
      await _vm.loadMore();
      if (_vm.assignments.length == before) break;
    }
  }

  List<DateTime> get _days =>
      List.generate(7, (i) => DateTime(_weekStart.year, _weekStart.month, _weekStart.day + i));

  Future<void> _downloadPdf() async {
    setState(() => _exporting = true);
    try {
      final days = _days;
      final inWeek = _vm.assignments
          .where((a) => days.any(a.isScheduledOn))
          .toList();
      await PdfService().generateSchedulePdf(
        assignments: inWeek,
        startDate: days.first,
        endDate: days.last,
        periodLabel: 'Week of ${DateFormat('MMM d').format(days.first)}',
      );
    } catch (e) {
      if (mounted) webToast(context, 'Could not create PDF: $e', error: true);
    }
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;
    final today = DateTime.now();
    // client name -> assignments with at least one visit this week
    final byClient = <String, List<Assignment>>{};
    for (final a in _vm.assignments) {
      if (days.any(a.isScheduledOn)) {
        byClient.putIfAbsent(a.clientName, () => []).add(a);
      }
    }
    final clients = byClient.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final visits = byClient.values
        .expand((l) => l)
        .fold<int>(0, (n, a) => n + days.where(a.isScheduledOn).length);

    return SingleChildScrollView(
      padding: WebTokens.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebPageHeader(
            title: 'Week of ${DateFormat('MMMM d, yyyy').format(days.first)}',
            subtitle: '${clients.length} clients · $visits visits scheduled',
            actions: [
              IconButton.outlined(
                tooltip: 'Previous week',
                onPressed: () => setState(() =>
                    _weekStart = _weekStart.subtract(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton.outlined(
                tooltip: 'Next week',
                onPressed: () => setState(() =>
                    _weekStart = _weekStart.add(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_right),
              ),
              OutlinedButton.icon(
                onPressed: _exporting || clients.isEmpty ? null : _downloadPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Download PDF'),
              ),
            ],
          ),
          if (_vm.isLoading && _vm.assignments.isEmpty)
            const WebCard(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (clients.isEmpty)
            const WebCard(
              padding: EdgeInsets.all(48),
              child: Center(
                child: WebEmptyState(
                    icon: Icons.event_busy_outlined,
                    message: 'No visits scheduled this week'),
              ),
            )
          else
            WebCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFFF9FAFC),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 180,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('CLIENT',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: AppTheme.textSecondary)),
                          ),
                        ),
                        for (final d in days)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                children: [
                                  Text(DateFormat('EEE').format(d),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textSecondary)),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 1),
                                    decoration: DateUtils.isSameDay(d, today)
                                        ? BoxDecoration(
                                            color: AppTheme.primaryColor,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          )
                                        : null,
                                    child: Text('${d.day}',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: DateUtils.isSameDay(d, today)
                                                ? Colors.white
                                                : AppTheme.textPrimary)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final c in clients)
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: WebTokens.border)),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 180,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(c,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                            for (final d in days)
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                        left: BorderSide(color: WebTokens.border)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      for (final a in byClient[c]!
                                          .where((a) => a.isScheduledOn(d)))
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 4),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: caregiverColor(a.caregiverId)
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border(
                                              left: BorderSide(
                                                  color: caregiverColor(
                                                      a.caregiverId),
                                                  width: 3),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(a.caregiverName,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: caregiverColor(
                                                          a.caregiverId))),
                                              Text(shiftLabel(a),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          AppTheme.textSecondary)),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
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
