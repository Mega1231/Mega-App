import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

class ManageUsersViewModel extends ChangeNotifier {
  final String role;
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int _pageSize = 15;

  List<AppUser> _users = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  DocumentSnapshot? _lastDoc;

  List<AppUser> get users => _users;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  int _totalCount = 0;
  int _activeCount = 0;
  int get totalCount => _totalCount;
  int get activeCount => _activeCount;
  int get inactiveCount => _totalCount - _activeCount;

  /// Usernames with pending password reset requests
  Set<String> _resetRequests = {};
  Set<String> get resetRequests => _resetRequests;
  bool hasResetRequest(AppUser user) => _resetRequests.contains(user.username);

  ManageUsersViewModel({required this.role});

  /// Initial fetch
  Future<void> loadUsers() async {
    _isLoading = true;
    _lastDoc = null;
    _hasMore = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _firestore
            .collection('users')
            .where('role', isEqualTo: role)
            .orderBy('createdAt', descending: true)
            .limit(_pageSize)
            .get(),
        _firestore
            .collection('users')
            .where('role', isEqualTo: role)
            .count()
            .get(),
        _firestore
            .collection('users')
            .where('role', isEqualTo: role)
            .where('isActive', isEqualTo: true)
            .count()
            .get(),
        _authService.getPendingResetUsernames(),
      ]);

      final snapshot = results[0] as QuerySnapshot;
      _users = snapshot.docs.map((d) => AppUser.fromFirestore(d)).toList();
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMore = snapshot.docs.length == _pageSize;

      _totalCount = (results[1] as AggregateQuerySnapshot).count ?? 0;
      _activeCount = (results[2] as AggregateQuerySnapshot).count ?? 0;
      _resetRequests = results[3] as Set<String>;
    } catch (e) {
      debugPrint('loadUsers error: $e');
      // Fallback: query without orderBy (doesn't need composite index)
      try {
        final snapshot = await _firestore
            .collection('users')
            .where('role', isEqualTo: role)
            .limit(_pageSize)
            .get();

        _users = snapshot.docs.map((d) => AppUser.fromFirestore(d)).toList();
        // Sort locally
        _users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _lastDoc = null; // No cursor pagination on fallback
        _hasMore = false;

        _totalCount = _users.length;
        _activeCount = _users.where((u) => u.isActive).length;
        try {
          _resetRequests = await _authService.getPendingResetUsernames();
        } catch (_) {}
      } catch (e2) {
        debugPrint('loadUsers fallback error: $e2');
        _error = 'Failed to load users.';
      }
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
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(_pageSize)
          .get();

      final newUsers =
          snapshot.docs.map((d) => AppUser.fromFirestore(d)).toList();
      _users.addAll(newUsers);
      _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : _lastDoc;
      _hasMore = snapshot.docs.length == _pageSize;
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
    await loadUsers();
  }

  /// Delete user completely
  Future<bool> deleteUser(AppUser user) async {
    try {
      await _authService.deleteUser(user.uid, user.username);
      _users.removeWhere((u) => u.uid == user.uid);
      _totalCount = (_totalCount - 1).clamp(0, _totalCount);
      if (user.isActive) {
        _activeCount = (_activeCount - 1).clamp(0, _activeCount);
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Toggle active status
  Future<bool> toggleUserActive(AppUser user) async {
    final newStatus = !user.isActive;
    try {
      await _authService.toggleUserActive(user.uid, newStatus);
      // Update local cache
      final index = _users.indexWhere((u) => u.uid == user.uid);
      if (index != -1) {
        _users[index] = AppUser(
          uid: user.uid,
          username: user.username,
          fullName: user.fullName,
          role: user.role,
          phone: user.phone,
          address: user.address,
          emergencyContact: user.emergencyContact,
          photoUrl: user.photoUrl,
          isActive: newStatus,
          createdAt: user.createdAt,
        );
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
