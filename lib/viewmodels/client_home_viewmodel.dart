import 'package:flutter/foundation.dart';
import '../models/assignment.dart';
import '../services/client_home_service.dart';

class ClientHomeViewModel extends ChangeNotifier {
  final String clientId;
  final ClientHomeService _service = ClientHomeService();

  bool _isLoading = false;
  List<Assignment> _assignments = [];

  // Primary caregiver info (from first active assignment)
  String? _caregiverName;
  String? _caregiverPhotoUrl;
  String? _caregiverId;
  String? _caregiverPhone;
  String? _schedule;

  bool get isLoading => _isLoading;
  List<Assignment> get assignments => _assignments;
  String? get caregiverName => _caregiverName;
  String? get caregiverPhotoUrl => _caregiverPhotoUrl;
  String? get caregiverId => _caregiverId;
  String? get caregiverPhone => _caregiverPhone;
  String? get schedule => _schedule;
  bool get hasCaregiver => _caregiverName != null;

  ClientHomeViewModel({required this.clientId});

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _assignments = await _service.getClientAssignments(clientId);

      if (_assignments.isNotEmpty) {
        final primary = _assignments.first;
        _caregiverName = primary.caregiverName;
        _caregiverPhotoUrl = primary.caregiverPhotoUrl;
        _caregiverId = primary.caregiverId;
        _schedule = primary.schedule;

        // Fetch caregiver's latest profile (photo may have been updated)
        final profile =
            await _service.getCaregiverProfile(primary.caregiverId);
        if (profile != null) {
          _caregiverPhone = profile['phone'] as String? ?? '';
          final latestPhoto = profile['photoUrl'] as String? ?? '';
          if (latestPhoto.isNotEmpty) {
            _caregiverPhotoUrl = latestPhoto;
          }
        }
      }
    } catch (e) {
      debugPrint('ClientHomeViewModel loadData error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadData();
  }
}
