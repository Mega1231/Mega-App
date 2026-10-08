import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import '../../services/pdf_service.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/report_viewmodel.dart';
import '../../widgets/reports_calendar.dart';
import '../common/report_list_widget.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  late ReportViewModel _reportVm;
  bool _isDownloading = false;
  DateTime _day = DateUtils.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    // The calendar loads the month and hands over the selected day.
    _reportVm = ReportViewModel();
  }

  @override
  void dispose() {
    _reportVm.dispose();
    super.dispose();
  }

  Future<void> _downloadReportsPdf() async {
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

      final reports =
          await ReportService().getReportsForDateRange(startDate, endDate);

      if (reports.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No shift reports found for this period.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      final filePath = await PdfService().generateBulkReportsPdf(
        reports: reports,
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
    return ChangeNotifierProvider.value(
      value: _reportVm,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('All Shift Reports'),
          actions: [
            IconButton(
              onPressed: _isDownloading ? null : _downloadReportsPdf,
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
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: ReportsCalendar(
                onDaySelected: (day, reports) {
                  setState(() => _day = day);
                  _reportVm.showReports(reports);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Text(
                    DateFormat('EEEE, MMM d').format(_day),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    '${_reportVm.reports.length} report${_reportVm.reports.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReportListWidget(
                emptyMessage: 'No shift reports on this day.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
