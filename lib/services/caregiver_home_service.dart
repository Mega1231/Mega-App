import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../models/assignment.dart';

class CaregiverHomeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch active assignments for this caregiver
  Future<List<Assignment>> getCaregiverAssignments(String caregiverId) async {
    try {
      final snapshot = await _firestore
          .collection('assignments')
          .where('caregiverId', isEqualTo: caregiverId)
          .where('isActive', isEqualTo: true)
          .get();
      final list =
          snapshot.docs.map((d) => Assignment.fromFirestore(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('getCaregiverAssignments error: $e');
      return [];
    }
  }

  /// Fetch client profile by ID
  Future<AppUser?> getClientProfile(String clientId) async {
    try {
      final doc = await _firestore.collection('users').doc(clientId).get();
      if (doc.exists) return AppUser.fromFirestore(doc);
      return null;
    } catch (e) {
      debugPrint('getClientProfile error: $e');
      return null;
    }
  }
}
