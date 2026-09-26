import 'package:cloud_firestore/cloud_firestore.dart';

class Assignment {
  final String id;
  final String clientId;
  final String clientName;
  final String clientPhotoUrl;
  final String caregiverId;
  final String caregiverName;
  final String caregiverPhotoUrl;
  final String schedule;
  final String shiftStartTime; // e.g. "10:00 AM"
  final String shiftEndTime;   // e.g. "2:00 PM"
  final String clientAddress;
  final double? clientLat;
  final double? clientLng;
  final bool isActive;
  final bool isLiveIn;
  final DateTime createdAt;
  final DateTime? startDate;
  final DateTime? endDate;

  Assignment({
    required this.id,
    required this.clientId,
    required this.clientName,
    this.clientPhotoUrl = '',
    required this.caregiverId,
    required this.caregiverName,
    this.caregiverPhotoUrl = '',
    required this.schedule,
    this.shiftStartTime = '',
    this.shiftEndTime = '',
    this.clientAddress = '',
    this.clientLat,
    this.clientLng,
    this.isActive = true,
    this.isLiveIn = false,
    DateTime? createdAt,
    this.startDate,
    this.endDate,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Assignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Assignment(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      clientPhotoUrl: data['clientPhotoUrl'] ?? '',
      caregiverId: data['caregiverId'] ?? '',
      caregiverName: data['caregiverName'] ?? '',
      caregiverPhotoUrl: data['caregiverPhotoUrl'] ?? '',
      schedule: data['schedule'] ?? '',
      shiftStartTime: data['shiftStartTime'] ?? '',
      shiftEndTime: data['shiftEndTime'] ?? '',
      clientAddress: data['clientAddress'] ?? '',
      clientLat: (data['clientLat'] as num?)?.toDouble(),
      clientLng: (data['clientLng'] as num?)?.toDouble(),
      isActive: data['isActive'] ?? true,
      isLiveIn: data['isLiveIn'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'clientPhotoUrl': clientPhotoUrl,
      'caregiverId': caregiverId,
      'caregiverName': caregiverName,
      'caregiverPhotoUrl': caregiverPhotoUrl,
      'schedule': schedule,
      'shiftStartTime': shiftStartTime,
      'shiftEndTime': shiftEndTime,
      'clientAddress': clientAddress,
      if (clientLat != null) 'clientLat': clientLat,
      if (clientLng != null) 'clientLng': clientLng,
      'isActive': isActive,
      'isLiveIn': isLiveIn,
      'createdAt': Timestamp.fromDate(createdAt),
      if (startDate != null) 'startDate': Timestamp.fromDate(startDate!),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
    };
  }
}
