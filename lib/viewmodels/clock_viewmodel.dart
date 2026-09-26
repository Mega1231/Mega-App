import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/assignment.dart';
import '../models/clock_record.dart';
import '../services/clock_service.dart';

class ClockViewModel extends ChangeNotifier {
  final ClockService _service = ClockService();
  final String caregiverId;
  final String caregiverName;
  final String caregiverPhotoUrl;

  ClockRecord? _activeRecord;
  List<ClockRecord> _todayRecords = [];
  bool _isLoading = false;
  bool _isClocking = false;
  String? _error;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  ClockRecord? get activeRecord => _activeRecord;
  List<ClockRecord> get todayRecords => _todayRecords;
  bool get isLoading => _isLoading;
  bool get isClocking => _isClocking;
  bool get isClockedIn => _activeRecord != null;
  String? get error => _error;
  Duration get elapsed => _elapsed;

  String get elapsedFormatted {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  ClockViewModel({
    required this.caregiverId,
    required this.caregiverName,
    this.caregiverPhotoUrl = '',
  });

  /// Load active clock-in and today's records.
  Future<void> loadData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _activeRecord = await _service.getActiveClockIn(caregiverId);
      if (_activeRecord != null) {
        _startTimer();
      }
    } catch (e) {
      debugPrint('ClockViewModel getActiveClockIn error: $e');
    }

    try {
      _todayRecords = await _service.getTodayRecords(caregiverId);
    } catch (e) {
      debugPrint('ClockViewModel getTodayRecords error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Clock in to an assignment.
  Future<bool> clockIn(Assignment assignment) async {
    _isClocking = true;
    _error = null;
    notifyListeners();

    try {
      _activeRecord = await _service.clockIn(
        assignment: assignment,
        caregiverId: caregiverId,
        caregiverName: caregiverName,
        caregiverPhotoUrl: caregiverPhotoUrl,
      );
      _startTimer();
      _isClocking = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isClocking = false;
      notifyListeners();
      return false;
    }
  }

  /// Clock out from current session.
  Future<bool> clockOut() async {
    if (_activeRecord == null) return false;

    _isClocking = true;
    _error = null;
    notifyListeners();

    try {
      await _service.clockOut(_activeRecord!.id);
      _stopTimer();
      // Refresh today's records
      _todayRecords = await _service.getTodayRecords(caregiverId);
      _activeRecord = null;
      _isClocking = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isClocking = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _startTimer() {
    _stopTimer();
    _updateElapsed();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateElapsed();
      notifyListeners();
    });
  }

  void _updateElapsed() {
    if (_activeRecord != null) {
      _elapsed = DateTime.now().difference(_activeRecord!.clockInTime);
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _elapsed = Duration.zero;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
