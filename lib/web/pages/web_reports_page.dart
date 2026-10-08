import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/shift_report.dart';
import '../../services/pdf_service.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/report_viewmodel.dart';
import '../admin_web_shell.dart';
import '../../widgets/reports_calendar.dart';
import '../web_widgets.dart';

/// All shift reports, grouped by visit day, with search, detail view and
/// PDF downloads.
class WebReportsPage extends StatefulWidget {
  /// When set, only this client's reports are shown.
  final String? clientId;
  final String? clientName;

  const WebReportsPage({super.key, this.clientId, this.clientName});

  bool get forClient => clientId != null;

  @override
  State<WebReportsPage> createState() => _WebReportsPageState();
}

class _WebReportsPageState extends State<WebReportsPage> {
  final _vm = ReportViewModel();
  String _query = '';
  bool _exporting = false;
  int _view = 0; // 0 calendar, 1 all reports (searchable list)
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  List<ShiftReport> _dayReports = [];

  @override
  void initState() {
    super.initState();
    _vm.addListener(_rebuild);
    _reload();
  }

  Future<void> _reload() => widget.forClient
      ? _vm.loadClientReports(widget.clientId!)
      : _vm.loadAllReports();

  void _loadMore() => widget.forClient
      ? _vm.loadMoreClientReports(widget.clientId!)
      : _vm.loadMoreAllReports();

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_rebuild);
    _vm.dispose();
    super.dispose();
  }

  List<ShiftReport> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _vm.reports;
    return _vm.reports
        .where((r) =>
            r.caregiverName.toLowerCase().contains(q) ||
            r.clientName.toLowerCase().contains(q) ||
            r.notes.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _exportPeriod(String period) async {
    setState(() => _exporting = true);
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = switch (period) {
        'Bi-Weekly' => today.subtract(const Duration(days: 14)),
        'Monthly' => DateTime(today.year, today.month - 1, today.day),
        _ => today.subtract(const Duration(days: 7)),
      };
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final reports = await ReportService().getReportsForDateRange(start, end);
      if (!mounted) return;
      if (reports.isEmpty) {
        webToast(context, 'No shift reports in this period', error: true);
      } else {
        await PdfService().generateBulkReportsPdf(
          reports: reports,
          startDate: start,
          endDate: end,
          periodLabel: period,
        );
      }
    } catch (e) {
      if (mounted) webToast(context, 'Could not create PDF: $e', error: true);
    }
    if (mounted) setState(() => _exporting = false);
  }

  Future<void> _downloadOne(ShiftReport r) async {
    try {
      await PdfService().generateShiftReportPdf(r);
    } catch (e) {
      if (mounted) webToast(context, 'Could not create PDF: $e', error: true);
    }
  }

  Widget _calendarView() {
    final list = WebCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DayHeader(date: _day, count: _dayReports.length),
          if (_dayReports.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: WebEmptyState(
                  icon: Icons.event_note_outlined,
                  message: 'No shift reports on this day'),
            )
          else
            for (final r in _dayReports)
              _ReportRow(
                report: r,
                onOpen: () => _openDetail(r),
                onPdf: () => _downloadOne(r),
              ),
        ],
      ),
    );
    final calendar = ReportsCalendar(
      clientId: widget.clientId,
      onDaySelected: (day, reports) => setState(() {
        _day = day;
        _dayReports = reports;
      }),
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 900) {
        return Column(children: [calendar, const SizedBox(height: 16), list]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 380, child: calendar),
          const SizedBox(width: 20),
          Expanded(child: list),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visible;
    // Reports come newest first; insert a header where the day changes.
    final children = <Widget>[];
    DateTime? day;
    for (final r in rows) {
      final d = DateUtils.dateOnly(r.visitDate);
      if (day == null || d != day) {
        day = d;
        final count =
            rows.where((x) => DateUtils.isSameDay(x.visitDate, d)).length;
        children.add(_DayHeader(date: d, count: count));
      }
      children.add(_ReportRow(
        report: r,
        onOpen: () => _openDetail(r),
        onPdf: () => _downloadOne(r),
      ));
    }

    return WebPageScaffold(
      onRefresh: _reload,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebPageHeader(
            title: widget.forClient
                ? '${widget.clientName} – Shift Reports'
                : 'Shift Reports',
            subtitle: widget.forClient
                ? 'Every report submitted for this client, newest first'
                : 'Submitted by caregivers after each visit',
            actions: [
              if (!widget.forClient)
              PopupMenuButton<String>(
                enabled: !_exporting,
                onSelected: _exportPeriod,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'Weekly', child: Text('Last 7 days')),
                  PopupMenuItem(value: 'Bi-Weekly', child: Text('Last 14 days')),
                  PopupMenuItem(value: 'Monthly', child: Text('Last month')),
                ],
                child: IgnorePointer(
                  child: FilledButton.icon(
                    onPressed: () {},
                    icon: _exporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Download PDF'),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              WebFilterTabs(
                labels: const ['Calendar', 'All reports'],
                selected: _view,
                onChanged: (i) => setState(() => _view = i),
              ),
              const SizedBox(width: 16),
              if (_view == 1)
                Text(
                  '${rows.length} report${rows.length == 1 ? '' : 's'} loaded',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
              const Spacer(),
              if (_view == 1)
                WebSearchField(
                  hint: 'Search caregiver, client, notes…',
                  onChanged: (v) => setState(() => _query = v),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_view == 0)
            _calendarView()
          else if (_vm.isLoading && _vm.reports.isEmpty)
            const WebCard(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (rows.isEmpty)
            const WebCard(
              padding: EdgeInsets.all(48),
              child: Center(
                child: WebEmptyState(
                    icon: Icons.description_outlined,
                    message: 'No shift reports found'),
              ),
            )
          else
            WebCard(
              padding: EdgeInsets.zero,
              child: Column(children: children),
            ),
          if (_view == 1 && _vm.hasMore && _query.isEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton(
                onPressed: _vm.isLoadingMore ? null : _loadMore,
                child: Text(_vm.isLoadingMore ? 'Loading…' : 'Load older reports'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openDetail(ShiftReport r) {
    showDialog(
      context: context,
      builder: (ctx) => _ReportDetailDialog(
        report: r,
        onPdf: () => _downloadOne(r),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime date;
  final int count;
  const _DayHeader({required this.date, required this.count});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label = DateFormat('EEEE, MMMM d, yyyy').format(date);
    if (DateUtils.isSameDay(date, now)) {
      label = 'Today · $label';
    } else if (DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Yesterday · $label';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFC),
        border: Border(bottom: BorderSide(color: WebTokens.border)),
      ),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Text('$count report${count == 1 ? '' : 's'}',
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _ReportRow extends StatefulWidget {
  final ShiftReport report;
  final VoidCallback onOpen;
  final VoidCallback onPdf;
  const _ReportRow(
      {required this.report, required this.onOpen, required this.onPdf});

  @override
  State<_ReportRow> createState() => _ReportRowState();
}

class _ReportRowState extends State<_ReportRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _hover ? WebTokens.rowHover : Colors.white,
            border: const Border(bottom: BorderSide(color: WebTokens.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    WebAvatar(
                        name: r.caregiverName,
                        photoUrl: r.caregiverPhotoUrl,
                        size: 34),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.caregiverName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          Text('for ${r.clientName}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(r.timeLabel, style: const TextStyle(fontSize: 13)),
              ),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final a in r.activitiesPerformed.take(3))
                          _Chip(a),
                        if (r.activitiesPerformed.length > 3)
                          _Chip('+${r.activitiesPerformed.length - 3}'),
                        if (r.imageUrls.isNotEmpty)
                          _Chip(
                              '${r.imageUrls.length} photo${r.imageUrls.length == 1 ? '' : 's'}',
                              icon: Icons.photo_camera_outlined),
                      ],
                    ),
                    if (r.notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          r.notes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Download PDF',
                onPressed: widget.onPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined,
                    size: 20, color: AppTheme.primaryColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  const _Chip(this.label, {this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppTheme.successColor),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.successColor)),
        ],
      ),
    );
  }
}

class _ReportDetailDialog extends StatelessWidget {
  final ShiftReport report;
  final VoidCallback onPdf;
  const _ReportDetailDialog({required this.report, required this.onPdf});

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final r = report;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 16, 16),
              child: Row(
                children: [
                  WebAvatar(
                      name: r.caregiverName,
                      photoUrl: r.caregiverPhotoUrl,
                      size: 44),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${r.caregiverName} → ${r.clientName}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(
                          '${DateFormat('EEEE, MMMM d, yyyy').format(r.visitDate)} · ${r.timeLabel}',
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('PDF'),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: WebTokens.border),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _section(
                      'Activities performed',
                      r.activitiesPerformed.isEmpty
                          ? const Text('—')
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final a in r.activitiesPerformed) _Chip(a),
                                ],
                              ),
                            ),
                    ),
                    if (r.clientCondition.isNotEmpty)
                      _section('Client condition',
                          Text(r.clientCondition, style: const TextStyle(fontSize: 14))),
                    _section(
                      'Notes',
                      Text(r.notes.isEmpty ? '—' : r.notes,
                          style: const TextStyle(fontSize: 14, height: 1.5)),
                    ),
                    if (r.imageUrls.isNotEmpty)
                      _section(
                        'Photos',
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final url in r.imageUrls)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  url,
                                  width: 200,
                                  height: 150,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 200,
                                    height: 150,
                                    color: WebTokens.pageBg,
                                    child: const Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              ),
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
    );
  }
}
