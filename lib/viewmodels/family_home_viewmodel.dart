import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../models/assignment.dart';

class FamilyHomeViewModel extends ChangeNotifier {
  final String familyUserId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  AppUser? _client;
  List<Assignment> _assignments = [];

  bool get isLoading => _isLoading;
  AppUser? get client => _client;
  List<Assignment> get assignments => _assignments;

  String? get caregiverName =>
      _assignments.isNotEmpty ? _assignments.first.caregiverName : null;
  String? get caregiverPhotoUrl =>
      _assignments.isNotEmpty ? _assignments.first.caregiverPhotoUrl : null;
  String? get caregiverId =>
      _assignments.isNotEmpty ? _assignments.first.caregiverId : null;
  bool get hasCaregiver => _assignments.isNotEmpty;

  FamilyHomeViewModel({required this.familyUserId});

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Get family user to find linked client
      final familyDoc =
          await _firestore.collection('users').doc(familyUserId).get();
      if (!familyDoc.exists) return;

      final familyUser = AppUser.fromFirestore(familyDoc);
      final clientId = familyUser.linkedClientId;
      if (clientId.isEmpty) return;

      // Load client profile
      final clientDoc =
          await _firestore.collection('users').doc(clientId).get();
      if (clientDoc.exists) {
        _client = AppUser.fromFirestore(clientDoc);
      }

      // Load assignments for this client
      final assignmentSnap = await _firestore
          .collection('assignments')
          .where('clientId', isEqualTo: clientId)
          .where('isActive', isEqualTo: true)
          .get();

      _assignments =
          assignmentSnap.docs.map((d) => Assignment.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('FamilyHomeViewModel loadData error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async => loadData();
}
