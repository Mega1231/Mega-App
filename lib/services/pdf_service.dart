import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/assignment.dart';
import '../models/shift_report.dart';
import 'download/file_download.dart';

class PdfService {
  /// Download image bytes from a URL.
  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (e) {
      debugPrint('Failed to download image for PDF: $e');
    }
    return null;
  }

  /// Generate a PDF for a shift report and return the file path
  Future<String> generateShiftReportPdf(ShiftReport report) async {
    final pdf = pw.Document();

    // Download all report images
    final List<pw.MemoryImage> pdfImages = [];
    for (final url in report.imageUrls) {
      final bytes = await _downloadImage(url);
      if (bytes != null) {
        pdfImages.add(pw.MemoryImage(bytes));
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated on ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
            pw.Text(
              'Mega Homecare Inc',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
        build: (context) {
          return [
            // Header
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1565C0'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'MEGA HOMECARE INC',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Shift Report',
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Report info section
            _buildInfoRow('Report Date',
                DateFormat('EEEE, MMMM d, yyyy').format(report.visitDate)),
            _buildInfoRow('Caregiver', report.caregiverName),
            _buildInfoRow('Client', report.clientName),
            _buildInfoRow('Shift Time',
                report.timeLabel),
            _buildInfoRow('Status', report.status.toUpperCase()),

            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 16),

            // Activities
            if (report.activitiesPerformed.isNotEmpty) ...[
              pw.Text(
                'Activities Performed',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              ...report.activitiesPerformed.map(
                (activity) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 6,
                        height: 6,
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#1565C0'),
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Text(activity,
                          style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // Client Condition
            if (report.clientCondition.isNotEmpty) ...[
              pw.Text(
                'Client Condition',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  report.clientCondition,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
              pw.SizedBox(height: 16),
            ],

            // Notes
            if (report.notes.isNotEmpty) ...[
              pw.Text(
                'Additional Notes',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  report.notes,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // Photos
            if (pdfImages.isNotEmpty) ...[
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 16),
              pw.Text(
                'Attached Photos (${pdfImages.length})',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              ...pdfImages.map(
                (img) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 16),
                  child: pw.ClipRRect(
                    horizontalRadius: 8,
                    verticalRadius: 8,
                    child: pw.Image(img,
                        height: 300, fit: pw.BoxFit.contain),
                  ),
                ),
              ),
            ],
          ];
        },
      ),
    );

    final fileName =
        'shift_report_${report.clientName.replaceAll(' ', '_')}_${DateFormat('yyyy-MM-dd').format(report.visitDate)}.pdf';
    return saveGeneratedFile(await pdf.save(), fileName);
  }

  /// Generate a professional schedule PDF for a date range and return the file path.
  Future<String> generateSchedulePdf({
    required List<Assignment> assignments,
    required DateTime startDate,
    required DateTime endDate,
    required String periodLabel,
  }) async {
    final pdf = pw.Document();
    final primaryColor = PdfColor.fromHex('#1565C0');
    final headerBg = PdfColor.fromHex('#E3F2FD');
    final altRowBg = PdfColor.fromHex('#F5F5F5');

    // Group assignments by caregiver name.
    final Map<String, List<Assignment>> grouped = {};
    for (final a in assignments) {
      grouped.putIfAbsent(a.caregiverName, () => []).add(a);
    }

    pw.Widget buildHeader() => pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            color: primaryColor,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'MEGA HOMECARE INC',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Schedule Report',
                style: const pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '$periodLabel  |  ${DateFormat('MMM d, yyyy').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}',
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        );

    List<pw.Widget> buildBody() {
      final widgets = <pw.Widget>[];
      widgets.add(buildHeader());
      widgets.add(pw.SizedBox(height: 24));

      for (final entry in grouped.entries) {
        final caregiverName = entry.key;
        final caregiverAssignments = entry.value;

        // Caregiver section header.
        widgets.add(
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              caregiverName,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 6));

        // Table header row.
        final columns = ['Client', 'Schedule Days', 'Shift Time', 'Address'];
        widgets.add(
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(2.5),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(3),
            },
            children: [
              // Header row.
              pw.TableRow(
                decoration: pw.BoxDecoration(color: headerBg),
                children: columns
                    .map(
                      (col) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: pw.Text(
                          col,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              // Data rows.
              ...caregiverAssignments.asMap().entries.map((e) {
                final idx = e.key;
                final a = e.value;
                final shiftTime =
                    (a.shiftStartTime.isNotEmpty && a.shiftEndTime.isNotEmpty)
                        ? '${a.shiftStartTime} - ${a.shiftEndTime}'
                        : a.schedule;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: idx.isOdd ? altRowBg : PdfColors.white,
                  ),
                  children: [
                    a.clientName,
                    a.schedule,
                    shiftTime,
                    a.clientAddress,
                  ]
                      .map(
                        (cell) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          child: pw.Text(
                            cell,
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                      )
                      .toList(),
                );
              }),
            ],
          ),
        );
        widgets.add(pw.SizedBox(height: 16));
      }

      return widgets;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated on ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
            pw.Text(
              'Mega Homecare Inc',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
        build: (context) => buildBody(),
      ),
    );

    final fileName =
        'schedule_${periodLabel.replaceAll(' ', '_')}_${DateFormat('yyyy-MM-dd').format(startDate)}.pdf';
    return saveGeneratedFile(await pdf.save(), fileName);
  }

  /// Generate a consolidated shift reports PDF and return the file path.
  Future<String> generateBulkReportsPdf({
    required List<ShiftReport> reports,
    required DateTime startDate,
    required DateTime endDate,
    required String periodLabel,
  }) async {
    final pdf = pw.Document();
    final primaryColor = PdfColor.fromHex('#1565C0');
    final headerBg = PdfColor.fromHex('#E3F2FD');
    final altRowBg = PdfColor.fromHex('#F5F5F5');

    // Summary statistics.
    final totalReports = reports.length;
    final totalCaregivers =
        reports.map((r) => r.caregiverName).toSet().length;
    final totalClients = reports.map((r) => r.clientName).toSet().length;

    pw.Widget buildHeader() => pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            color: primaryColor,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'MEGA HOMECARE INC',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Shift Reports Summary',
                style: const pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '$periodLabel  |  ${DateFormat('MMM d, yyyy').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}',
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        );

    pw.Widget buildStatsBox() => pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: headerBg,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColor.fromHex('#BBDEFB'), width: 1),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildStatCell('Total Reports', '$totalReports', primaryColor),
              _buildStatCell('Caregivers', '$totalCaregivers', primaryColor),
              _buildStatCell('Clients', '$totalClients', primaryColor),
            ],
          ),
        );

    List<pw.Widget> buildBody() {
      final columns = ['Date', 'Caregiver', 'Client', 'Time', 'Activities', 'Status'];

      final dataRows = reports.asMap().entries.map((e) {
        final idx = e.key;
        final r = e.value;
        return pw.TableRow(
          decoration: pw.BoxDecoration(
            color: idx.isOdd ? altRowBg : PdfColors.white,
          ),
          children: [
            DateFormat('MMM d, yyyy').format(r.visitDate),
            r.caregiverName,
            r.clientName,
            r.timeLabel,
            r.activitiesPerformed.join(', '),
            r.status.toUpperCase(),
          ]
              .map(
                (cell) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6, vertical: 5),
                  child: pw.Text(
                    cell,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              )
              .toList(),
        );
      }).toList();

      return [
        buildHeader(),
        pw.SizedBox(height: 16),
        buildStatsBox(),
        pw.SizedBox(height: 20),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(2),
            4: pw.FlexColumnWidth(3),
            5: pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: headerBg),
              children: columns
                  .map(
                    (col) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6, vertical: 6),
                      child: pw.Text(
                        col,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            ...dataRows,
          ],
        ),
      ];
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated on ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
            pw.Text(
              'Mega Homecare Inc',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
        build: (context) => buildBody(),
      ),
    );

    final fileName =
        'shift_reports_${periodLabel.replaceAll(' ', '_')}_${DateFormat('yyyy-MM-dd').format(startDate)}.pdf';
    return saveGeneratedFile(await pdf.save(), fileName);
  }

  /// Client schedule as a month calendar (caregiver name and time per day).
  Future<String> generateClientSchedulePdf({
    required String clientName,
    required List<Assignment> assignments,
  }) async {
    final pdf = pw.Document();
    final headerBg = PdfColor.fromHex('#F5F5F5');
    final nameColor = PdfColor.fromHex('#E91E63');
    final borderColor = PdfColors.grey400;
    final now = DateTime.now();

    // Determine calendar range from assignments
    DateTime? earliest;
    DateTime? latest;
    for (final a in assignments) {
      if (a.startDate != null) {
        if (earliest == null || a.startDate!.isBefore(earliest)) {
          earliest = a.startDate!;
        }
      }
      if (a.endDate != null) {
        if (latest == null || a.endDate!.isAfter(latest)) {
          latest = a.endDate!;
        }
      }
    }
    earliest ??= now;
    latest ??= now.add(const Duration(days: 30));

    // Expand to full weeks (Monday start)
    final calStart = earliest.subtract(Duration(days: earliest.weekday - 1));
    final calEnd = latest.add(Duration(days: 7 - latest.weekday));

    // Build weeks
    final weeks = <List<DateTime>>[];
    var day = calStart;
    while (!day.isAfter(calEnd)) {
      final week = <DateTime>[];
      for (int i = 0; i < 7; i++) {
        week.add(day);
        day = day.add(const Duration(days: 1));
      }
      weeks.add(week);
    }

    // 4 weeks per page — big readable cells
    const weeksPerPage = 4;
    final totalPages = (weeks.length / weeksPerPage).ceil();

    for (int page = 0; page < totalPages; page++) {
      final pageWeeks = weeks.skip(page * weeksPerPage).take(weeksPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header: client name left, date right
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        clientName,
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        DateFormat('EEEE, MMM d yyyy').format(now),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),

                // Calendar grid
                pw.Expanded(
                  child: pw.Table(
                    border: pw.TableBorder.all(color: borderColor, width: 0.5),
                    columnWidths: const {
                      0: pw.FlexColumnWidth(1),
                      1: pw.FlexColumnWidth(1),
                      2: pw.FlexColumnWidth(1),
                      3: pw.FlexColumnWidth(1),
                      4: pw.FlexColumnWidth(1),
                      5: pw.FlexColumnWidth(1),
                      6: pw.FlexColumnWidth(1),
                    },
                    children: [
                      // Day name header row
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: headerBg),
                        children: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
                            .map((d) => pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(vertical: 6),
                                  child: pw.Center(
                                    child: pw.Text(
                                      d,
                                      style: pw.TextStyle(
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                      // Week rows
                      ...pageWeeks.map((week) {
                        return pw.TableRow(
                          children: week.map((date) {
                            final active = assignments
                                .where((a) => a.isScheduledOn(date))
                                .toList();

                            return pw.Container(
                              padding: const pw.EdgeInsets.all(3),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  // Day number
                                  pw.Text(
                                    '${date.day}',
                                    style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  if (active.isNotEmpty) pw.SizedBox(height: 2),
                                  // Assignment entries
                                  ...active.map((a) {
                                    final time = a.isLiveIn
                                        ? 'Live-in'
                                        : (a.shiftStartTime.isNotEmpty && a.shiftEndTime.isNotEmpty)
                                            ? '${a.shiftStartTime}-${a.shiftEndTime}'
                                            : '';
                                    return pw.Padding(
                                      padding: const pw.EdgeInsets.only(bottom: 4),
                                      child: pw.Column(
                                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                                        children: [
                                          pw.Text(
                                            a.caregiverName,
                                            style: pw.TextStyle(
                                              fontSize: 8,
                                              fontWeight: pw.FontWeight.bold,
                                              color: nameColor,
                                            ),
                                            textAlign: pw.TextAlign.center,
                                          ),
                                          if (time.isNotEmpty)
                                            pw.Text(
                                              time,
                                              style: const pw.TextStyle(fontSize: 7),
                                              textAlign: pw.TextAlign.center,
                                            ),
                                          pw.Text(
                                            'Timetracking',
                                            style: const pw.TextStyle(fontSize: 6),
                                            textAlign: pw.TextAlign.center,
                                          ),
                                          pw.Text(
                                            'Confirmed',
                                            style: const pw.TextStyle(fontSize: 6),
                                            textAlign: pw.TextAlign.center,
                                          ),
                                          pw.Text(
                                            'Mega Homecare Inc',
                                            style: const pw.TextStyle(fontSize: 6),
                                            textAlign: pw.TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      }),
                    ],
                  ),
                ),

                // Footer
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Mega Homecare Inc',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'Page ${page + 1} of $totalPages',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    final fileName =
        'schedule_${clientName.replaceAll(' ', '_')}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
    return saveGeneratedFile(await pdf.save(), fileName);
  }

  pw.Widget _buildStatCell(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
