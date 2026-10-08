import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';

class AssignmentViewModel extends ChangeNotifier {
  final AssignmentService _service = AssignmentService();

  static const int _pageSize = 15;

  List<Assignment> _assignments = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  DocumentSnapshot? _lastDoc;

  // For create form dropdowns
  List<AppUser> _clients = [];
  List<AppUser> _caregivers = [];
  bool _isLoadingDropdowns = false;

  // Creating state
  bool _isCreating = false;

  List<Assignment> get assignments => _assignments;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  List<AppUser> get clients => _clients;
  List<AppUser> get caregivers => _caregivers;
  bool get isLoadingDropdowns => _isLoadingDropdowns;
  bool get isCreating => _isCreating;

  /// Initial fetch
  Future<void> loadAssignments() async {
    _isLoading = true;
    _lastDoc = null;
    _hasMore = true;
    _error = null;
    notifyListeners();

    try {
      final page = await _service.getAssignments(limit: _pageSize);
      _assignments = page.assignments;
      _lastDoc = page.lastDoc;
      _hasMore = page.hasMore;
    } catch (e) {
      debugPrint('loadAssignments error: $e');
      _error = 'Failed to load assignments.';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load next page
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _lastDoc == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _service.getAssignments(
        startAfter: _lastDoc,
        limit: _pageSize,
      );
      _assignments.addAll(page.assignments);
      _lastDoc = page.lastDoc ?? _lastDoc;
      _hasMore = page.hasMore;
    } catch (_) {
      _hasMore = false;
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  /// Pull to refresh
  Future<void> refresh() async {
    _lastDoc = null;
    _hasMore = true;
    await loadAssignments();
  }

  /// Load clients & caregivers for create form
  Future<void> loadDropdownData() async {
    _isLoadingDropdowns = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.getActiveClients(),
        _service.getActiveCaregivers(),
      ]);
      _clients = results[0];
      _caregivers = results[1];
    } catch (e) {
      debugPrint('loadDropdownData error: $e');
    }

    _isLoadingDropdowns = false;
    notifyListeners();
  }

  /// Create assignment
  Future<bool> createAssignment({
    required AppUser client,
    required AppUser caregiver,
    required String schedule,
    String shiftStartTime = '',
    String shiftEndTime = '',
    bool isLiveIn = false,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isCreating = true;
    notifyListeners();

    try {
      await _service.createAssignment(
        client: client,
        caregiver: caregiver,
        schedule: schedule,
        shiftStartTime: shiftStartTime,
        shiftEndTime: shiftEndTime,
        isLiveIn: isLiveIn,
        startDate: startDate,
        endDate: endDate,
      );
      _isCreating = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('createAssignment error: $e');
      _isCreating = false;
      notifyListeners();
      return false;
    }
  }

  /// Create group assignment (1 client + multiple caregivers with individual times)
  Future<bool> createGroupAssignment({
    required AppUser client,
    required Map<AppUser, Map<String, dynamic>> caregiverSchedules,
  }) async {
    _isCreating = true;
    notifyListeners();

    try {
      for (final entry in caregiverSchedules.entries) {
        final caregiver = entry.key;
        final data = entry.value;
        await _service.createAssignment(
          client: client,
          caregiver: caregiver,
          schedule: data['schedule'] as String? ?? '',
          shiftStartTime: data['startTime'] as String? ?? '',
          shiftEndTime: data['endTime'] as String? ?? '',
          startDate: data['startDate'] as DateTime?,
          endDate: data['endDate'] as DateTime?,
        );
      }
      _isCreating = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('createGroupAssignment error: $e');
      _isCreating = false;
      notifyListeners();
      return false;
    }
  }

  /// Check if a caregiver has a conflicting assignment on the same days/times.
  /// Returns a description of the conflict, or null if available.
  Future<String?> checkCaregiverAvailability({
    required String caregiverId,
    required Set<String> days,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async {
    try {
      final existing = await _service.getCaregiverAssignments(caregiverId);
      final newStart = startTime.hour * 60 + startTime.minute;
      final newEnd = endTime.hour * 60 + endTime.minute;

      for (final a in existing) {
        // Check if any selected day overlaps with existing assignment days
        final overlappingDays = days.where((d) => a.schedule.contains(d)).toList();
        if (overlappingDays.isEmpty) continue;

        // Parse existing assignment times
        final timeMatch = RegExp(
          r'(\d{1,2}:\d{2}\s*[APap][Mm])\s*-\s*(\d{1,2}:\d{2}\s*[APap][Mm])',
        ).firstMatch(a.schedule);
        if (timeMatch == null) continue;

        final existStart = _parseTimeToMinutes(timeMatch.group(1)!);
        final existEnd = _parseTimeToMinutes(timeMatch.group(2)!);
        if (existStart == null || existEnd == null) continue;

        // Check time overlap
        if (newStart < existEnd && existStart < newEnd) {
          final dayStr = overlappingDays.join(', ');
          return '${a.caregiverName} is already assigned to ${a.clientName} '
              'on $dayStr (${a.shiftStartTime} - ${a.shiftEndTime})';
        }
      }
      return null;
    } catch (e) {
      debugPrint('checkCaregiverAvailability error: $e');
      return null;
    }
  }

  int? _parseTimeToMinutes(String timeStr) {
    try {
      final parts = timeStr.trim().toUpperCase().split(RegExp(r'[:\s]+'));
      var hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = parts[2]; // AM or PM
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return hour * 60 + minute;
    } catch (_) {
      return null;
    }
  }

  /// Delete assignment
  Future<bool> deleteAssignment(String id) async {
    try {
      await _service.deleteAssignment(id);
      _assignments.removeWhere((a) => a.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('deleteAssignment error: $e');
      return false;
    }
  }

  /// Give an assignment to another caregiver from [from] onward.
  Future<bool> changeCaregiver(
      String id, AppUser caregiver, DateTime from) async {
    try {
      await _service.changeCaregiver(id, caregiver, from);
      return true;
    } catch (e) {
      debugPrint('changeCaregiver error: $e');
      return false;
    }
  }

  /// Update schedule
  Future<bool> updateSchedule(
    String id,
    String schedule, {
    String? shiftStartTime,
    String? shiftEndTime,
    DateTime? startDate,
    DateTime? endDate,
    bool? isLiveIn,
  }) async {
    try {
      await _service.updateSchedule(
        id,
        schedule,
        shiftStartTime: shiftStartTime,
        shiftEndTime: shiftEndTime,
        startDate: startDate,
        endDate: endDate,
        isLiveIn: isLiveIn,
      );
      final index = _assignments.indexWhere((a) => a.id == id);
      if (index != -1) {
        final old = _assignments[index];
        _assignments[index] = Assignment(
          id: old.id,
          clientId: old.clientId,
          clientName: old.clientName,
          clientPhotoUrl: old.clientPhotoUrl,
          caregiverId: old.caregiverId,
          caregiverName: old.caregiverName,
          caregiverPhotoUrl: old.caregiverPhotoUrl,
          schedule: schedule,
          shiftStartTime: shiftStartTime ?? old.shiftStartTime,
          shiftEndTime: shiftEndTime ?? old.shiftEndTime,
          clientAddress: old.clientAddress,
          clientLat: old.clientLat,
          clientLng: old.clientLng,
          isActive: old.isActive,
          createdAt: old.createdAt,
          startDate: startDate ?? old.startDate,
          endDate: endDate ?? old.endDate,
          isLiveIn: isLiveIn ?? old.isLiveIn,
          excludedDates: old.excludedDates,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('updateSchedule error: $e');
      return false;
    }
  }
}
