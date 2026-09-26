import 'dart:io';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class CreateUserViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _error;
  bool _success = false;
  String? _createdClientUid;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get success => _success;

  Future<bool> createUser({
    required String username,
    required String password,
    required String fullName,
    required String role,
    String address = '',
    double? latitude,
    double? longitude,
    String emergencyContact = '',
    File? photo,
    File? noteFile,
    String noteFileName = '',
  }) async {
    _isLoading = true;
    _error = null;
    _success = false;
    notifyListeners();

    try {
      final uid = await _authService.createUser(
        username: username,
        password: password,
        fullName: fullName,
        role: role,
        address: address,
        latitude: latitude,
        longitude: longitude,
        emergencyContact: emergencyContact,
        photo: photo,
        noteFile: noteFile,
        noteFileName: noteFileName,
      );
      _createdClientUid = uid;
      _success = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> createFamilyMember({
    required String username,
    required String password,
    required String fullName,
  }) async {
    if (_createdClientUid == null) return false;
    try {
      await _authService.createFamilyMember(
        username: username,
        password: password,
        fullName: fullName,
        linkedClientId: _createdClientUid!,
      );
      return true;
    } catch (e) {
      _error = _parseError(e);
      return false;
    }
  }

  void reset() {
    _isLoading = false;
    _error = null;
    _success = false;
    notifyListeners();
  }

  String _parseError(dynamic e) {
    final message = e.toString();
    if (message.contains('username-exists')) {
      return 'This username is already taken.';
    }
    if (message.contains('email-already-in-use')) {
      return 'This username is already taken.';
    }
    if (message.contains('weak-password')) {
      return 'Password must be at least 6 characters.';
    }
    return 'Failed to create user. Please try again.';
  }
}
