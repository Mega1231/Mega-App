import 'package:cloud_firestore/cloud_firestore.dart';

class ClockRecord {
  final String id;
  final String assignmentId;
  final String caregiverId;
  final String caregiverName;
  final String caregiverPhotoUrl;
  final String clientId;
  final String clientName;
  final String clientAddress;
  final DateTime clockInTime;
  final double clockInLat;
  final double clockInLng;
  final DateTime? clockOutTime;
  final double? clockOutLat;
  final double? clockOutLng;
  final double? totalHours;
  final String status; // 'clocked_in', 'completed'

  ClockRecord({
    required this.id,
    required this.assignmentId,
    required this.caregiverId,
    required this.caregiverName,
    this.caregiverPhotoUrl = '',
    required this.clientId,
    required this.clientName,
    this.clientAddress = '',
    required this.clockInTime,
    required this.clockInLat,
    required this.clockInLng,
    this.clockOutTime,
    this.clockOutLat,
    this.clockOutLng,
    this.totalHours,
    this.status = 'clocked_in',
  });

  factory ClockRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClockRecord(
      id: doc.id,
      assignmentId: data['assignmentId'] ?? '',
      caregiverId: data['caregiverId'] ?? '',
      caregiverName: data['caregiverName'] ?? '',
      caregiverPhotoUrl: data['caregiverPhotoUrl'] ?? '',
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      clientAddress: data['clientAddress'] ?? '',
      clockInTime:
          (data['clockInTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      clockInLat: (data['clockInLat'] as num?)?.toDouble() ?? 0,
      clockInLng: (data['clockInLng'] as num?)?.toDouble() ?? 0,
      clockOutTime: (data['clockOutTime'] as Timestamp?)?.toDate(),
      clockOutLat: (data['clockOutLat'] as num?)?.toDouble(),
      clockOutLng: (data['clockOutLng'] as num?)?.toDouble(),
      totalHours: (data['totalHours'] as num?)?.toDouble(),
      status: data['status'] ?? 'clocked_in',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'assignmentId': assignmentId,
      'caregiverId': caregiverId,
      'caregiverName': caregiverName,
      'caregiverPhotoUrl': caregiverPhotoUrl,
      'clientId': clientId,
      'clientName': clientName,
      'clientAddress': clientAddress,
      'clockInTime': Timestamp.fromDate(clockInTime),
      'clockInLat': clockInLat,
      'clockInLng': clockInLng,
      if (clockOutTime != null)
        'clockOutTime': Timestamp.fromDate(clockOutTime!),
      if (clockOutLat != null) 'clockOutLat': clockOutLat,
      if (clockOutLng != null) 'clockOutLng': clockOutLng,
      if (totalHours != null) 'totalHours': totalHours,
      'status': status,
    };
  }
}
