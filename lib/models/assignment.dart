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
  // Single days removed from the recurring schedule, as 'yyyy-MM-dd'.
  final List<String> excludedDates;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  bool isExcludedOn(DateTime date) => excludedDates.contains(dateKey(date));

  /// Whether this recurring assignment has a visit on [date]: right weekday,
  /// inside start/end dates, and that day not removed.
  bool isScheduledOn(DateTime date) {
    final days = schedule.split('|').first;
    if (!days.contains(_weekdays[date.weekday - 1])) return false;
    final day = DateTime(date.year, date.month, date.day);
    if (startDate != null &&
        day.isBefore(DateTime(startDate!.year, startDate!.month, startDate!.day))) {
      return false;
    }
    if (endDate != null &&
        day.isAfter(DateTime(endDate!.year, endDate!.month, endDate!.day))) {
      return false;
    }
    return !isExcludedOn(date);
  }

  /// Whether there is a visit on any day of the Monday–Sunday week that
  /// [date] falls in. Clients, family and caregivers only see each other
  /// while they are scheduled together that week.
  bool isScheduledInWeekOf(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    for (var i = 0; i < 7; i++) {
      if (isScheduledOn(DateTime(monday.year, monday.month, monday.day + i))) {
        return true;
      }
    }
    return false;
  }

  /// One assignment per caregiver among those scheduled this week, by name.
  static List<Assignment> caregiversThisWeek(Iterable<Assignment> all) {
    final now = DateTime.now();
    final byCaregiver = <String, Assignment>{};
    for (final a in all) {
      if (a.isScheduledInWeekOf(now)) byCaregiver.putIfAbsent(a.caregiverId, () => a);
    }
    return byCaregiver.values.toList()
      ..sort((a, b) =>
          a.caregiverName.toLowerCase().compareTo(b.caregiverName.toLowerCase()));
  }

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
    this.excludedDates = const [],
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
      excludedDates: List<String>.from(data['excludedDates'] ?? []),
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
      if (excludedDates.isNotEmpty) 'excludedDates': excludedDates,
    };
  }
}
