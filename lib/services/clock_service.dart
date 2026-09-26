import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/assignment.dart';
import '../models/clock_record.dart';

class ClockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const double _clockInRadiusMeters = 100.0;

  /// Check if location services are enabled and permission is granted.
  /// Returns the current position or throws.
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permission permanently denied. Please enable in Settings.');
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  /// Calculate distance between two coordinates in meters.
  double getDistance(
      double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Check if caregiver is within range of the client's address.
  bool isWithinRange(Position position, double clientLat, double clientLng) {
    final distance = getDistance(
        position.latitude, position.longitude, clientLat, clientLng);
    return distance <= _clockInRadiusMeters;
  }

  /// Clock in: verify GPS, create record.
  Future<ClockRecord> clockIn({
    required Assignment assignment,
    required String caregiverId,
    required String caregiverName,
    required String caregiverPhotoUrl,
  }) async {
    final position = await getCurrentPosition();

    if (assignment.clientLat == null || assignment.clientLng == null) {
      throw Exception(
          'Client address coordinates not set. Contact your admin.');
    }

    if (!isWithinRange(position, assignment.clientLat!, assignment.clientLng!)) {
      final distance = getDistance(
        position.latitude,
        position.longitude,
        assignment.clientLat!,
        assignment.clientLng!,
      );
      throw Exception(
          'You are ${distance.round()}m away from the client\'s location. '
          'You must be within ${_clockInRadiusMeters.round()}m to clock in.');
    }

    final record = ClockRecord(
      id: '',
      assignmentId: assignment.id,
      caregiverId: caregiverId,
      caregiverName: caregiverName,
      caregiverPhotoUrl: caregiverPhotoUrl,
      clientId: assignment.clientId,
      clientName: assignment.clientName,
      clientAddress: assignment.clientAddress,
      clockInTime: DateTime.now(),
      clockInLat: position.latitude,
      clockInLng: position.longitude,
      status: 'clocked_in',
    );

    final docRef =
        await _firestore.collection('clock_records').add(record.toMap());
    return ClockRecord(
      id: docRef.id,
      assignmentId: record.assignmentId,
      caregiverId: record.caregiverId,
      caregiverName: record.caregiverName,
      caregiverPhotoUrl: record.caregiverPhotoUrl,
      clientId: record.clientId,
      clientName: record.clientName,
      clientAddress: record.clientAddress,
      clockInTime: record.clockInTime,
      clockInLat: record.clockInLat,
      clockInLng: record.clockInLng,
      status: 'clocked_in',
    );
  }

  /// Clock out: update existing record with out time + hours.
  Future<void> clockOut(String recordId) async {
    final position = await getCurrentPosition();
    final now = DateTime.now();

    final doc =
        await _firestore.collection('clock_records').doc(recordId).get();
    if (!doc.exists) throw Exception('Clock record not found.');

    final record = ClockRecord.fromFirestore(doc);
    final duration = now.difference(record.clockInTime);
    final hours =
        double.parse((duration.inMinutes / 60).toStringAsFixed(2));

    await _firestore.collection('clock_records').doc(recordId).update({
      'clockOutTime': Timestamp.fromDate(now),
      'clockOutLat': position.latitude,
      'clockOutLng': position.longitude,
      'totalHours': hours,
      'status': 'completed',
    });
  }

  /// Get active clock-in for a caregiver (if any).
  Future<ClockRecord?> getActiveClockIn(String caregiverId) async {
    final snapshot = await _firestore
        .collection('clock_records')
        .where('caregiverId', isEqualTo: caregiverId)
        .where('status', isEqualTo: 'clocked_in')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return ClockRecord.fromFirestore(snapshot.docs.first);
  }

  /// Get today's clock records for a caregiver.
  Future<List<ClockRecord>> getTodayRecords(String caregiverId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    try {
      final snapshot = await _firestore
          .collection('clock_records')
          .where('caregiverId', isEqualTo: caregiverId)
          .where('clockInTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .orderBy('clockInTime', descending: true)
          .get();

      return snapshot.docs.map((d) => ClockRecord.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('getTodayRecords index error, using fallback: $e');
      // Fallback without orderBy (works without composite index)
      final snapshot = await _firestore
          .collection('clock_records')
          .where('caregiverId', isEqualTo: caregiverId)
          .where('clockInTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      final records =
          snapshot.docs.map((d) => ClockRecord.fromFirestore(d)).toList();
      records.sort((a, b) => b.clockInTime.compareTo(a.clockInTime));
      return records;
    }
  }

  /// Get all clock records (admin) with pagination.
  Future<List<ClockRecord>> getAllRecords({
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    try {
      Query query = _firestore
          .collection('clock_records')
          .orderBy('clockInTime', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((d) => ClockRecord.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('getAllRecords error: $e');
      // Fallback without orderBy
      try {
        final snapshot = await _firestore
            .collection('clock_records')
            .limit(limit)
            .get();
        final records =
            snapshot.docs.map((d) => ClockRecord.fromFirestore(d)).toList();
        records.sort((a, b) => b.clockInTime.compareTo(a.clockInTime));
        return records;
      } catch (_) {
        return [];
      }
    }
  }

  /// Get currently clocked-in caregivers (admin live view).
  Future<List<ClockRecord>> getActiveClockins() async {
    final snapshot = await _firestore
        .collection('clock_records')
        .where('status', isEqualTo: 'clocked_in')
        .get();

    return snapshot.docs.map((d) => ClockRecord.fromFirestore(d)).toList();
  }

  /// Get clock records for a date range (admin reports).
  Future<List<ClockRecord>> getRecordsByDateRange(
      DateTime start, DateTime end) async {
    try {
      final snapshot = await _firestore
          .collection('clock_records')
          .where('clockInTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('clockInTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('clockInTime', descending: true)
          .get();

      return snapshot.docs.map((d) => ClockRecord.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('getRecordsByDateRange index error, using fallback: $e');
      final snapshot = await _firestore
          .collection('clock_records')
          .where('clockInTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('clockInTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();
      final records =
          snapshot.docs.map((d) => ClockRecord.fromFirestore(d)).toList();
      records.sort((a, b) => b.clockInTime.compareTo(a.clockInTime));
      return records;
    }
  }
}
