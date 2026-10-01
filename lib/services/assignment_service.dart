import 'package:cloud_firestore/cloud_firestore.dart';
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
  }) async {
    final data = <String, dynamic>{'schedule': schedule};
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
