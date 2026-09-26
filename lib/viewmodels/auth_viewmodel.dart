import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _fcmTokenSub;

  AppUser? _currentUser;
  bool _isInitializing = true; // Only true during app startup auth check
  bool _isLoggingIn = false;   // True while login() is in progress
  String? _error;

  AppUser? get currentUser => _currentUser;
  bool get isInitializing => _isInitializing;
  bool get isLoggingIn => _isLoggingIn;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;

  /// Listen to Firebase Auth state and load profile when logged in
  void init() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser == null) {
        _currentUser = null;
        _isInitializing = false;
        notifyListeners();
        return;
      }

      // Logged in — load Firestore profile (only show full-screen loader on cold start)
      if (!_isLoggingIn) {
        _isInitializing = true;
        notifyListeners();
      }

      try {
        _currentUser = await _authService.getCurrentUser();
        if (_currentUser != null && !_currentUser!.isActive) {
          await _authService.signOut();
          _currentUser = null;
        } else if (_currentUser != null) {
          await _setupFcmToken(_currentUser!.uid);
        }
      } catch (_) {
        _currentUser = null;
      }

      _isInitializing = false;
      notifyListeners();
    });
  }

  /// Best-effort push notification setup — must never block login.
  /// getToken() throws on iOS simulators (no APNs token) and when
  /// notification services are unavailable.
  Future<void> _setupFcmToken(String uid) async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      await _authService.saveFcmToken(uid);
      _fcmTokenSub?.cancel();
      _fcmTokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _authService.saveFcmToken(uid);
      });
    } catch (e) {
      debugPrint('FCM setup skipped: $e');
    }
  }

  /// Login with username and password
  Future<bool> login(String username, String password) async {
    _isLoggingIn = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signIn(username, password);
      await _setupFcmToken(_currentUser!.uid);
      _isLoggingIn = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoggingIn = false;
      _error = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    if (_currentUser != null) {
      try {
        await _authService.removeFcmToken(_currentUser!.uid);
      } catch (_) {}
    }
    _fcmTokenSub?.cancel();
    _fcmTokenSub = null;
    await _authService.signOut();
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  /// Update profile photo: upload to Storage, update Firestore, refresh local user
  Future<String> updateProfilePhoto(File photo) async {
    if (_currentUser == null) throw Exception('Not logged in');
    final newUrl = await _authService.updateUserProfilePhoto(_currentUser!.uid, photo);
    _currentUser = await _authService.getCurrentUser();
    notifyListeners();
    return newUrl;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _parseError(dynamic e) {
    final message = e.toString();
    if (message.contains('user-not-found') ||
        message.contains('invalid-credential')) {
      return 'Invalid username or password.';
    }
    if (message.contains('user-disabled')) {
      return 'Your account has been deactivated. Contact your administrator.';
    }
    if (message.contains('wrong-password')) {
      return 'Invalid username or password.';
    }
    if (message.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }
    if (message.contains('network-request-failed')) {
      return 'No internet connection.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _fcmTokenSub?.cancel();
    super.dispose();
  }
}
