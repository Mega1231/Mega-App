import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get count using aggregate query (1 read instead of N)
  Future<int> getUserCount(String role) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('getUserCount error: $e');
      return 0;
    }
  }

  /// Get active user count
  Future<int> getActiveUserCount(String role) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .where('isActive', isEqualTo: true)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('getActiveUserCount error: $e');
      return 0;
    }
  }

  /// Fetch recent users (last N created)
  Future<List<AppUser>> getRecentUsers({int limit = 5}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('getRecentUsers error: $e');
      // Fallback: fetch without orderBy and sort locally
      try {
        final snapshot = await _firestore
            .collection('users')
            .limit(limit)
            .get();
        final users =
            snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
        users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return users;
      } catch (_) {
        return [];
      }
    }
  }
}
