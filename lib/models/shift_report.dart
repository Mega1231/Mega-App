import 'package:cloud_firestore/cloud_firestore.dart';

class ShiftReport {
  final String id;
  final String caregiverId;
  final String caregiverName;
  final String clientId;
  final String clientName;
  final String clientPhotoUrl;
  final String caregiverPhotoUrl;
  final DateTime visitDate;
  final String startTime;
  final String endTime;
  final List<String> activitiesPerformed;
  final String clientCondition;
  final String notes;
  final List<String> imageUrls;
  final String status; // 'submitted', 'reviewed'
  final DateTime createdAt;

  ShiftReport({
    required this.id,
    required this.caregiverId,
    required this.caregiverName,
    required this.clientId,
    required this.clientName,
    this.clientPhotoUrl = '',
    this.caregiverPhotoUrl = '',
    required this.visitDate,
    required this.startTime,
    required this.endTime,
    required this.activitiesPerformed,
    this.clientCondition = '',
    this.notes = '',
    this.imageUrls = const [],
    this.status = 'submitted',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Older live-in reports were saved as 'Live-in (8 hrs)'.
  bool get isLiveIn => startTime.startsWith('Live-in');

  String get timeLabel => isLiveIn ? 'Live-in' : '$startTime – $endTime';

  factory ShiftReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShiftReport(
      id: doc.id,
      caregiverId: data['caregiverId'] ?? '',
      caregiverName: data['caregiverName'] ?? '',
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      clientPhotoUrl: data['clientPhotoUrl'] ?? '',
      caregiverPhotoUrl: data['caregiverPhotoUrl'] ?? '',
      visitDate: (data['visitDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      activitiesPerformed: List<String>.from(data['activitiesPerformed'] ?? []),
      clientCondition: data['clientCondition'] ?? '',
      notes: data['notes'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      status: data['status'] ?? 'submitted',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'caregiverId': caregiverId,
      'caregiverName': caregiverName,
      'clientId': clientId,
      'clientName': clientName,
      'clientPhotoUrl': clientPhotoUrl,
      'caregiverPhotoUrl': caregiverPhotoUrl,
      'visitDate': Timestamp.fromDate(visitDate),
      'startTime': startTime,
      'endTime': endTime,
      'activitiesPerformed': activitiesPerformed,
      'clientCondition': clientCondition,
      'notes': notes,
      'imageUrls': imageUrls,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
