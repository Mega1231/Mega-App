import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/dashboard_service.dart';

class DashboardViewModel extends ChangeNotifier {
  final DashboardService _service = DashboardService();

  int _clientCount = 0;
  int _caregiverCount = 0;
  int _activeClientCount = 0;
  int _activeCaregiverCount = 0;
  List<AppUser> _recentUsers = [];
  bool _isLoading = false;
  DateTime? _lastFetched;

  int get clientCount => _clientCount;
  int get caregiverCount => _caregiverCount;
  int get activeClientCount => _activeClientCount;
  int get activeCaregiverCount => _activeCaregiverCount;
  List<AppUser> get recentUsers => _recentUsers;
  bool get isLoading => _isLoading;

  /// Load dashboard data with smart caching
  /// Only re-fetches if data is older than 2 minutes or forced
  Future<void> loadData({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _lastFetched != null &&
        DateTime.now().difference(_lastFetched!).inMinutes < 2) {
      return; // Use cached data
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Fetch all counts in parallel (each is 1 read)
      final results = await Future.wait([
        _service.getUserCount('client'),
        _service.getUserCount('caregiver'),
        _service.getActiveUserCount('client'),
        _service.getActiveUserCount('caregiver'),
        _service.getRecentUsers(limit: 5),
      ]);

      _clientCount = results[0] as int;
      _caregiverCount = results[1] as int;
      _activeClientCount = results[2] as int;
      _activeCaregiverCount = results[3] as int;
      _recentUsers = results[4] as List<AppUser>;
      _lastFetched = DateTime.now();
    } catch (_) {
      // Keep stale data on error
    }

    _isLoading = false;
    notifyListeners();
  }
}
