import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/assignment.dart';

class ClientHomeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch assignments for this client
  Future<List<Assignment>> getClientAssignments(String clientId) async {
    try {
      final snapshot = await _firestore
          .collection('assignments')
          .where('clientId', isEqualTo: clientId)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map((d) => Assignment.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('getClientAssignments error: $e');
      return [];
    }
  }

  /// Fetch caregiver profile by ID
  Future<Map<String, dynamic>?> getCaregiverProfile(
      String caregiverId) async {
    try {
      final doc =
          await _firestore.collection('users').doc(caregiverId).get();
      if (doc.exists) return doc.data();
      return null;
    } catch (e) {
      debugPrint('getCaregiverProfile error: $e');
      return null;
    }
  }
}
