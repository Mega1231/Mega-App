import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import '../models/shift_report.dart';
import '../services/pdf_service.dart';
import '../services/report_service.dart';

class ReportViewModel extends ChangeNotifier {
  final ReportService _service = ReportService();
  final PdfService _pdfService = PdfService();

  List<ShiftReport> _reports = [];
  List<ShiftReport> get reports => _reports;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;

  String? _error;
  String? get error => _error;

  DocumentSnapshot? _lastDoc;

  /// Show an already-fetched set of reports (e.g. one day picked on the
  /// reports calendar). Nothing more to page in.
  void showReports(List<ShiftReport> reports) {
    _reports = reports;
    _lastDoc = null;
    _hasMore = false;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Load reports for a caregiver
  Future<void> loadCaregiverReports(String caregiverId) async {
    _isLoading = true;
    _reports = [];
    _lastDoc = null;
    _hasMore = true;
    notifyListeners();

    try {
      final snapshot = await _service.getRawReportsByCaregiver(caregiverId);
      _reports =
          snapshot.docs.map((doc) => ShiftReport.fromFirestore(doc)).toList();
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMore = snapshot.docs.length >= ReportService.reportsPerPage;
    } catch (e) {
      debugPrint('loadCaregiverReports error: $e');
      _error = 'Failed to load reports: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load reports for a client
  Future<void> loadClientReports(String clientId) async {
    _isLoading = true;
    _reports = [];
    _lastDoc = null;
    _hasMore = true;
    notifyListeners();

    try {
      final snapshot = await _service.getRawReportsByClient(clientId);
      _reports =
          snapshot.docs.map((doc) => ShiftReport.fromFirestore(doc)).toList();
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMore = snapshot.docs.length >= ReportService.reportsPerPage;
    } catch (e) {
      debugPrint('loadClientReports error: $e');
      _error = 'Failed to load reports: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load all reports (admin)
  Future<void> loadAllReports() async {
    _isLoading = true;
    _reports = [];
    _lastDoc = null;
    _hasMore = true;
    notifyListeners();

    try {
      final snapshot = await _service.getRawAllReports();
      _reports =
          snapshot.docs.map((doc) => ShiftReport.fromFirestore(doc)).toList();
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMore = snapshot.docs.length >= ReportService.reportsPerPage;
    } catch (e) {
      _error = 'Failed to load reports: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load reports for a caregiver's assigned clients (all reports for those clients)
  Future<void> loadCaregiverClientReports(List<String> clientIds) async {
    _isLoading = true;
    _reports = [];
    _lastDoc = null;
    _hasMore = true;
    notifyListeners();

    try {
      final snapshot =
          await _service.getRawReportsByClientIds(clientIds);
      _reports =
          snapshot.docs.map((doc) => ShiftReport.fromFirestore(doc)).toList();
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMore = snapshot.docs.length >= ReportService.reportsPerPage;
    } catch (e) {
      debugPrint('loadCaregiverClientReports error: $e');
      _error = 'Failed to load reports: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreCaregiverClientReports(List<String> clientIds) async {
    if (_isLoadingMore || !_hasMore || _lastDoc == null) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final snapshot = await _service.getRawReportsByClientIds(
        clientIds,
        startAfter: _lastDoc,
      );
      final more =
          snapshot.docs.map((doc) => ShiftReport.fromFirestore(doc)).toList();
      _reports.addAll(more);
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : _lastDoc;
      _hasMore = snapshot.docs.length >= ReportService.reportsPerPage;
    } catch (e) {
      _error = 'Failed to load more reports';
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  /// Load more (pagination)
  Future<void> loadMoreCaregiverReports(String caregiverId) async {
    if (_isLoadingMore || !_hasMore || _lastDoc == null) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final snapshot = await _service.getRawReportsByCaregiver(
        caregiverId,
        startAfter: _lastDoc,
      );
      final more =
          snapshot.docs.map((doc) => ShiftReport.fromFirestore(doc)).toList();
      _reports.addAll(more);
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : _lastDoc;
      _hasMore = snapshot.docs.length >= ReportService.reportsPerPage;
    } catch (e) {
      _error = 'Failed to load more reports';
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> loadMoreClientReports(String clientId) async {
    if (_isLoadingMore || !_hasMore || _lastDoc == null) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final snapshot = await _service.getRawReportsByClient(
        clientId,
        startAfter: _lastDoc,
      );
      final more =
          snapshot.docs.map((doc) => ShiftReport.fromFirestore(doc)).toList();
      _reports.addAll(more);
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : _lastDoc;
      _hasMore = snapshot.docs.length >= ReportService.reportsPerPage;
    } catch (e) {
      _error = 'Failed to load more reports';
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> loadMoreAllReports() async {
    if (_isLoadingMore || !_hasMore || _lastDoc == null) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final snapshot = await _service.getRawAllReports(startAfter: _lastDoc);
      final more =
          snapshot.docs.map((doc) => ShiftReport.fromFirestore(doc)).toList();
      _reports.addAll(more);
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : _lastDoc;
      _hasMore = snapshot.docs.length >= ReportService.reportsPerPage;
    } catch (e) {
      _error = 'Failed to load more reports';
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  /// Download report as PDF
  Future<void> downloadPdf(ShiftReport report) async {
    _isDownloading = true;
    notifyListeners();

    try {
      final filePath = await _pdfService.generateShiftReportPdf(report);
      await OpenFile.open(filePath);
    } catch (e) {
      _error = 'Failed to generate PDF: $e';
    }

    _isDownloading = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
