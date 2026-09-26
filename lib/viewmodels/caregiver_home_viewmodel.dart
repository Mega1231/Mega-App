import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/app_user.dart';
import '../models/assignment.dart';
import '../services/caregiver_home_service.dart';

class CaregiverHomeViewModel extends ChangeNotifier {
  final String caregiverId;
  final CaregiverHomeService _service = CaregiverHomeService();

  bool _isLoading = false;
  List<Assignment> _assignments = [];
  // clientId → AppUser (for address/phone)
  final Map<String, AppUser> _clientProfiles = {};

  bool get isLoading => _isLoading;
  List<Assignment> get assignments => _assignments;
  int get clientCount => _assignments.length;
  Map<String, AppUser> get clientProfiles => _clientProfiles;

  CaregiverHomeViewModel({required this.caregiverId});

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _assignments = await _service.getCaregiverAssignments(caregiverId);

      // Fetch client profiles in parallel for address info
      final futures = <Future>[];
      for (final a in _assignments) {
        if (!_clientProfiles.containsKey(a.clientId)) {
          futures.add(
            _service.getClientProfile(a.clientId).then((profile) {
              if (profile != null) {
                _clientProfiles[a.clientId] = profile;
              }
            }),
          );
        }
      }
      await Future.wait(futures);
    } catch (e) {
      debugPrint('CaregiverHomeViewModel loadData error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    _clientProfiles.clear();
    await loadData();
  }

  /// Get visit-day assignments for a given day name (e.g. "Mon")
  /// Optionally pass a date to filter by start/end date range.
  /// Results are sorted by shift start time (ascending).
  List<Assignment> getAssignmentsForDay(String dayShort, {DateTime? date}) {
    final filtered = _assignments.where((a) {
      if (!a.schedule.contains(dayShort)) return false;
      if (date != null) {
        final dateOnly = DateTime(date.year, date.month, date.day);
        if (a.startDate != null) {
          final start = DateTime(a.startDate!.year, a.startDate!.month, a.startDate!.day);
          if (dateOnly.isBefore(start)) return false;
        }
        if (a.endDate != null) {
          final end = DateTime(a.endDate!.year, a.endDate!.month, a.endDate!.day);
          if (dateOnly.isAfter(end)) return false;
        }
      }
      return true;
    }).toList();

    // Sort by shift start time ascending
    filtered.sort((a, b) {
      final aMin = _timeToMinutes(a.shiftStartTime);
      final bMin = _timeToMinutes(b.shiftStartTime);
      return aMin.compareTo(bMin);
    });

    return filtered;
  }

  /// Parse "9:00 AM" → minutes since midnight for sorting.
  int _timeToMinutes(String timeStr) {
    try {
      final dt = DateFormat('h:mm a').parse(timeStr.trim());
      return dt.hour * 60 + dt.minute;
    } catch (_) {
      return 0;
    }
  }
}
