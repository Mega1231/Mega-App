import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shift_report.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';

/// Month calendar of shift reports: each day shows how many reports were
/// filed, and tapping a day reports that day's list through [onDaySelected].
/// Used by the admin reports screen on mobile and web.
class ReportsCalendar extends StatefulWidget {
  /// Called with the picked day and its reports, newest first.
  final void Function(DateTime day, List<ShiftReport> reports) onDaySelected;

  /// Only this client's reports, when set.
  final String? clientId;

  const ReportsCalendar({super.key, required this.onDaySelected, this.clientId});

  @override
  State<ReportsCalendar> createState() => _ReportsCalendarState();
}

class _ReportsCalendarState extends State<ReportsCalendar> {
  final _service = ReportService();
  late DateTime _month;
  late DateTime _selected;
  List<ShiftReport> _monthReports = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _month = DateTime(today.year, today.month);
    _selected = today;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final start = DateTime(_month.year, _month.month, 1);
    final end = DateTime(_month.year, _month.month + 1, 1)
        .subtract(const Duration(seconds: 1));
    try {
      var reports = await _service.getReportsForDateRange(start, end);
      if (widget.clientId != null) {
        reports = reports.where((r) => r.clientId == widget.clientId).toList();
      }
      _monthReports = reports;
    } catch (_) {
      _monthReports = [];
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _emit();
  }

  List<ShiftReport> _on(DateTime d) => _monthReports
      .where((r) => DateUtils.isSameDay(r.visitDate, d))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  void _emit() => widget.onDaySelected(_selected, _on(_selected));

  void _shift(int months) {
    setState(() {
      _month = DateTime(_month.year, _month.month + months);
      // Keep a selection inside the visible month.
      final today = DateUtils.dateOnly(DateTime.now());
      _selected = (today.year == _month.year && today.month == _month.month)
          ? today
          : DateTime(_month.year, _month.month, 1);
    });
    _load();
  }

  void _pick(DateTime d) {
    setState(() => _selected = d);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday - 1; // Monday-first
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E8EF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => _shift(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(_month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => _shift(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(d,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (int r = 0; r < rows; r++)
            Row(
              children: [
                for (int c = 0; c < 7; c++)
                  Expanded(child: _cell(r * 7 + c - lead + 1, daysInMonth, today)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(int dayNumber, int daysInMonth, DateTime today) {
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 46);
    }
    final d = DateTime(_month.year, _month.month, dayNumber);
    final count = _on(d).length;
    final selected = DateUtils.isSameDay(d, _selected);
    final isToday = DateUtils.isSameDay(d, today);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: selected
            ? AppTheme.primaryColor
            : count > 0
                ? AppTheme.primaryColor.withValues(alpha: 0.07)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _pick(d),
          child: Container(
            height: 42,
            decoration: isToday && !selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryColor, width: 1.5),
                  )
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                if (count > 0)
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppTheme.primaryColor,
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
