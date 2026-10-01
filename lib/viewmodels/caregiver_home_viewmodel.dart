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
  // clientId → active family members of that client
  final Map<String, List<AppUser>> _familyMembers = {};

  bool get isLoading => _isLoading;
  List<Assignment> get assignments => _assignments;
  int get clientCount => _assignments.length;
  Map<String, AppUser> get clientProfiles => _clientProfiles;
  List<AppUser> familyMembersOf(String clientId) =>
      _familyMembers[clientId] ?? const [];

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

      await Future.wait(_clientProfiles.entries
          .where((e) => !_familyMembers.containsKey(e.key))
          .map((e) async {
        final members = await Future.wait(
            e.value.familyMemberIds.map(_service.getClientProfile));
        _familyMembers[e.key] = members
            .whereType<AppUser>()
            .where((m) => m.isActive)
            .toList();
      }));
    } catch (e) {
      debugPrint('CaregiverHomeViewModel loadData error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    _clientProfiles.clear();
    _familyMembers.clear();
    await loadData();
  }

  /// Assignments with a visit on [date], sorted by shift start time.
  List<Assignment> getAssignmentsForDate(DateTime date) {
    final filtered =
        _assignments.where((a) => a.isScheduledOn(date)).toList();

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
