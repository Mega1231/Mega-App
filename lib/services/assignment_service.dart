import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../models/assignment.dart';

class AssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new assignment
  Future<void> createAssignment({
    required AppUser client,
    required AppUser caregiver,
    required String schedule,
    String shiftStartTime = '',
    String shiftEndTime = '',
    bool isLiveIn = false,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final assignment = Assignment(
      id: '',
      clientId: client.uid,
      clientName: client.fullName,
      clientPhotoUrl: client.photoUrl,
      caregiverId: caregiver.uid,
      caregiverName: caregiver.fullName,
      caregiverPhotoUrl: caregiver.photoUrl,
      schedule: schedule,
      shiftStartTime: shiftStartTime,
      shiftEndTime: shiftEndTime,
      isLiveIn: isLiveIn,
      clientAddress: client.address,
      clientLat: client.latitude,
      clientLng: client.longitude,
      startDate: startDate,
      endDate: endDate,
    );

    await _firestore.collection('assignments').add(assignment.toMap());
  }

  /// Fetch assignments with pagination
  Future<AssignmentPage> getAssignments({
    DocumentSnapshot? startAfter,
    int limit = 15,
  }) async {
    try {
      Query query = _firestore
          .collection('assignments')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final assignments =
          snapshot.docs.map((d) => Assignment.fromFirestore(d)).toList();
      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      final hasMore = snapshot.docs.length == limit;

      return AssignmentPage(
        assignments: assignments,
        lastDoc: lastDoc,
        hasMore: hasMore,
      );
    } catch (e) {
      debugPrint('getAssignments error: $e');
      // Fallback without orderBy
      try {
        final snapshot = await _firestore
            .collection('assignments')
            .limit(limit)
            .get();
        final assignments =
            snapshot.docs.map((d) => Assignment.fromFirestore(d)).toList();
        assignments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return AssignmentPage(
          assignments: assignments,
          lastDoc: null,
          hasMore: false,
        );
      } catch (_) {
        return AssignmentPage(assignments: [], lastDoc: null, hasMore: false);
      }
    }
  }

  /// Delete assignment
  Future<void> deleteAssignment(String id) async {
    await _firestore.collection('assignments').doc(id).delete();
  }

  /// Update assignment schedule
  Future<void> updateSchedule(
    String id,
    String schedule, {
    String? shiftStartTime,
    String? shiftEndTime,
    DateTime? startDate,
    DateTime? endDate,
    bool? isLiveIn,
  }) async {
    final data = <String, dynamic>{'schedule': schedule};
    if (isLiveIn != null) data['isLiveIn'] = isLiveIn;
    if (shiftStartTime != null) data['shiftStartTime'] = shiftStartTime;
    if (shiftEndTime != null) data['shiftEndTime'] = shiftEndTime;
    if (startDate != null) {
      data['startDate'] = Timestamp.fromDate(startDate);
    }
    if (endDate != null) {
      data['endDate'] = Timestamp.fromDate(endDate);
    }
    await _firestore.collection('assignments').doc(id).update(data);
  }

  /// Hands a recurring assignment to another caregiver from [from] onward.
  /// Days before [from] keep the original caregiver: the old assignment ends
  /// the day before and a copy for the new caregiver starts on [from]. If
  /// the assignment hasn't started by then, the caregiver is just swapped.
  Future<void> changeCaregiver(
      String assignmentId, AppUser caregiver, DateTime from) async {
    final ref = _firestore.collection('assignments').doc(assignmentId);
    final old = Assignment.fromFirestore(await ref.get());
    final day = DateTime(from.year, from.month, from.day);
    final caregiverFields = {
      'caregiverId': caregiver.uid,
      'caregiverName': caregiver.fullName,
      'caregiverPhotoUrl': caregiver.photoUrl,
    };

    final start = old.startDate == null
        ? null
        : DateTime(old.startDate!.year, old.startDate!.month, old.startDate!.day);
    if (start == null || !day.isAfter(start)) {
      await ref.update(caregiverFields);
      return;
    }

    final dayBefore = day.subtract(const Duration(days: 1));
    String withRange(String schedule, DateTime s, DateTime? e) {
      final parts = schedule.split('|').map((p) => p.trim()).toList();
      final fmt = DateFormat('MMM d, yyyy');
      final range = '${fmt.format(s)} - ${e == null ? '' : fmt.format(e)}'.trim();
      if (parts.length >= 3) {
        parts[parts.length - 1] = range;
      } else {
        parts.add(range);
      }
      return parts.join(' | ');
    }

    final newData = old.toMap()
      ..addAll(caregiverFields)
      ..['startDate'] = Timestamp.fromDate(day)
      ..['schedule'] = withRange(old.schedule, day, old.endDate)
      ..['excludedDates'] = old.excludedDates
          .where((k) => k.compareTo(Assignment.dateKey(day)) >= 0)
          .toList()
      ..['createdAt'] = Timestamp.now();

    final batch = _firestore.batch();
    batch.update(ref, {
      'endDate': Timestamp.fromDate(dayBefore),
      'schedule': withRange(old.schedule, start, dayBefore),
    });
    batch.set(_firestore.collection('assignments').doc(), newData);
    await batch.commit();
  }

  /// Remove a single day from a recurring assignment (e.g. a missed visit).
  Future<void> excludeDate(String assignmentId, DateTime date) async {
    await _firestore.collection('assignments').doc(assignmentId).update({
      'excludedDates': FieldValue.arrayUnion([Assignment.dateKey(date)]),
    });
  }

  Future<void> restoreDate(String assignmentId, DateTime date) async {
    await _firestore.collection('assignments').doc(assignmentId).update({
      'excludedDates': FieldValue.arrayRemove([Assignment.dateKey(date)]),
    });
  }

  /// Fetch active assignments for a client
  Future<List<Assignment>> getClientAssignments(String clientId) async {
    final snapshot = await _firestore
        .collection('assignments')
        .where('clientId', isEqualTo: clientId)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map((d) => Assignment.fromFirestore(d)).toList();
  }

  /// Fetch active assignments for a caregiver
  Future<List<Assignment>> getCaregiverAssignments(String caregiverId) async {
    final snapshot = await _firestore
        .collection('assignments')
        .where('caregiverId', isEqualTo: caregiverId)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map((d) => Assignment.fromFirestore(d)).toList();
  }

  /// Fetch active clients (for dropdown)
  Future<List<AppUser>> getActiveClients() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'client')
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map((d) => AppUser.fromFirestore(d)).toList();
  }

  /// Fetch active caregivers (for dropdown)
  Future<List<AppUser>> getActiveCaregivers() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'caregiver')
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map((d) => AppUser.fromFirestore(d)).toList();
  }
}

class AssignmentPage {
  final List<Assignment> assignments;
  final DocumentSnapshot? lastDoc;
  final bool hasMore;

  AssignmentPage({
    required this.assignments,
    required this.lastDoc,
    required this.hasMore,
  });
}
