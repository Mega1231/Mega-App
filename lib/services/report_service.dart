import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/shift_report.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const int reportsPerPage = 15;

  /// Create a new shift report
  Future<void> createReport(ShiftReport report) async {
    await _firestore.collection('shift_reports').add(report.toMap());
  }

  /// Upload report images and return download URLs
  Future<List<String>> uploadReportImages(
      String caregiverId, List<File> images) async {
    final urls = <String>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < images.length; i++) {
      final ref = _storage
          .ref()
          .child('report_images/$caregiverId/${timestamp}_$i.jpg');
      await ref.putFile(images[i]);
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  /// Get all shift reports within a date range (for weekly hours tracking)
  Future<List<ShiftReport>> getReportsForDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final snapshot = await _firestore
        .collection('shift_reports')
        .where('visitDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('visitDate', isLessThan: Timestamp.fromDate(end))
        .orderBy('visitDate')
        .get();
    return snapshot.docs.map((d) => ShiftReport.fromFirestore(d)).toList();
  }

  /// Get reports for multiple clients (caregiver seeing all assigned client reports)
  Future<List<ShiftReport>> getReportsByClientIds(
    List<String> clientIds, {
    DocumentSnapshot? startAfter,
    int limit = reportsPerPage,
  }) async {
    if (clientIds.isEmpty) return [];

    // Firestore 'whereIn' supports max 30 values per query
    final chunks = <List<String>>[];
    for (var i = 0; i < clientIds.length; i += 30) {
      chunks.add(clientIds.sublist(
          i, i + 30 > clientIds.length ? clientIds.length : i + 30));
    }

    final allReports = <ShiftReport>[];
    for (final chunk in chunks) {
      Query query = _firestore
          .collection('shift_reports')
          .where('clientId', whereIn: chunk)
          .orderBy('visitDate', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      allReports
          .addAll(snapshot.docs.map((d) => ShiftReport.fromFirestore(d)));
    }

    allReports.sort((a, b) => b.visitDate.compareTo(a.visitDate));
    return allReports.take(limit).toList();
  }

  Future<QuerySnapshot> getRawReportsByClientIds(
    List<String> clientIds, {
    DocumentSnapshot? startAfter,
    int limit = reportsPerPage,
  }) async {
    if (clientIds.isEmpty) {
      return await _firestore
          .collection('shift_reports')
          .where('clientId', isEqualTo: '__none__')
          .limit(1)
          .get();
    }

    Query query = _firestore
        .collection('shift_reports')
        .where('clientId', whereIn: clientIds.take(30).toList())
        .orderBy('visitDate', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return await query.get();
  }

  /// Get reports by caregiver (paginated)
  Future<List<ShiftReport>> getReportsByCaregiver(
    String caregiverId, {
    DocumentSnapshot? startAfter,
    int limit = reportsPerPage,
  }) async {
    Query query = _firestore
        .collection('shift_reports')
        .where('caregiverId', isEqualTo: caregiverId)
        .orderBy('visitDate', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => ShiftReport.fromFirestore(doc)).toList();
  }

  /// Get reports for a client (paginated)
  Future<List<ShiftReport>> getReportsByClient(
    String clientId, {
    DocumentSnapshot? startAfter,
    int limit = reportsPerPage,
  }) async {
    Query query = _firestore
        .collection('shift_reports')
        .where('clientId', isEqualTo: clientId)
        .orderBy('visitDate', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => ShiftReport.fromFirestore(doc)).toList();
  }

  /// Get all reports (admin, paginated)
  Future<List<ShiftReport>> getAllReports({
    DocumentSnapshot? startAfter,
    int limit = reportsPerPage,
  }) async {
    Query query = _firestore
        .collection('shift_reports')
        .orderBy('visitDate', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => ShiftReport.fromFirestore(doc)).toList();
  }

  /// Get the last Firestore DocumentSnapshot for pagination cursor
  Future<DocumentSnapshot?> getLastDocument(
    String collection, {
    String? field,
    String? value,
    int limit = reportsPerPage,
  }) async {
    Query query = _firestore
        .collection('shift_reports')
        .orderBy('visitDate', descending: true)
        .limit(limit);

    if (field != null && value != null) {
      query = query.where(field, isEqualTo: value);
    }

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.last;
  }

  /// Get raw document snapshot for pagination
  Future<QuerySnapshot> getRawReportsByCaregiver(
    String caregiverId, {
    DocumentSnapshot? startAfter,
    int limit = reportsPerPage,
  }) async {
    Query query = _firestore
        .collection('shift_reports')
        .where('caregiverId', isEqualTo: caregiverId)
        .orderBy('visitDate', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return await query.get();
  }

  Future<QuerySnapshot> getRawReportsByClient(
    String clientId, {
    DocumentSnapshot? startAfter,
    int limit = reportsPerPage,
  }) async {
    Query query = _firestore
        .collection('shift_reports')
        .where('clientId', isEqualTo: clientId)
        .orderBy('visitDate', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return await query.get();
  }

  Future<QuerySnapshot> getRawAllReports({
    DocumentSnapshot? startAfter,
    int limit = reportsPerPage,
  }) async {
    Query query = _firestore
        .collection('shift_reports')
        .orderBy('visitDate', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return await query.get();
  }
}
