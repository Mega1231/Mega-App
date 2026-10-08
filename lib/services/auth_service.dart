import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _emailDomain = 'megahomecare.app';

  String _usernameToEmail(String username) =>
      '${username.toLowerCase().trim()}@$_emailDomain';

  User? get currentFirebaseUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with username and password
  Future<AppUser> signIn(String username, String password) async {
    final email = _usernameToEmail(username);
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();

    if (!doc.exists) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'User profile not found.',
      );
    }

    final user = AppUser.fromFirestore(doc);

    if (!user.isActive) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'user-disabled',
        message: 'Your account has been deactivated. Contact your administrator.',
      );
    }

    return user;
  }

  /// Get current AppUser from Firestore
  /// If the Firestore doc doesn't exist (e.g. admin created via Firebase Console),
  /// auto-creates the profile.
  Future<AppUser?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    final doc =
        await _firestore.collection('users').doc(firebaseUser.uid).get();

    if (doc.exists) {
      final user = AppUser.fromFirestore(doc);
      if (!user.isActive) {
        await _auth.signOut();
        return null;
      }
      return user;
    }

    // Only auto-create profile for the very first admin user (created via
    // Firebase Console).  Check if ANY admin already exists — if so, this is
    // a deleted user whose Firestore doc is gone; sign them out.
    final adminsSnap = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .limit(1)
        .get();

    if (adminsSnap.docs.isNotEmpty) {
      // An admin already exists — this user was deleted, sign out
      await _auth.signOut();
      return null;
    }

    // First-time setup: create the initial admin profile
    final email = firebaseUser.email ?? '';
    final username = email.contains('@') ? email.split('@').first : email;

    final newUser = AppUser(
      uid: firebaseUser.uid,
      username: username,
      fullName: firebaseUser.displayName ?? 'Administrator',
      role: 'admin',
    );

    await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .set(newUser.toMap());

    return newUser;
  }

  /// Admin creates a new user account
  /// Uses a secondary Firebase App so the admin stays logged in
  /// Upload user profile photo and return the download URL
  Future<String> uploadProfilePhoto(String uid, File photo) async =>
      uploadProfilePhotoBytes(uid, await photo.readAsBytes());

  /// Byte-based upload, used by the web admin (no dart:io File there).
  Future<String> uploadProfilePhotoBytes(String uid, Uint8List bytes) async {
    final ref = _storage.ref().child('profile_photos/$uid.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  /// Update user profile fields in Firestore.
  Future<void> updateUser({
    required String uid,
    required String fullName,
    String address = '',
    double? latitude,
    double? longitude,
    String emergencyContact = '',
    String phone = '',
    File? photo,
    File? noteFile,
    String? noteFileName,
    Uint8List? photoBytes,
    Uint8List? noteBytes,
  }) async {
    final data = <String, dynamic>{
      'fullName': fullName,
      'address': address,
      'emergencyContact': emergencyContact,
      'phone': phone,
    };
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;

    final photoData = photoBytes ?? await photo?.readAsBytes();
    if (photoData != null) {
      data['photoUrl'] = await uploadProfilePhotoBytes(uid, photoData);
    }

    final noteData = noteBytes ?? await noteFile?.readAsBytes();
    if (noteData != null && noteFileName != null) {
      data['clientNoteUrl'] =
          await uploadClientNoteBytes(uid, noteData, noteFileName);
      data['clientNoteFileName'] = noteFileName;
    }

    await _firestore.collection('users').doc(uid).update(data);
  }

  /// Update user's profile photo: upload to Storage and update Firestore
  Future<String> updateUserProfilePhoto(String uid, File photo) async =>
      updateUserProfilePhotoBytes(uid, await photo.readAsBytes());

  Future<String> updateUserProfilePhotoBytes(String uid, Uint8List bytes) async {
    final photoUrl = await uploadProfilePhotoBytes(uid, bytes);
    await _firestore.collection('users').doc(uid).update({'photoUrl': photoUrl});
    return photoUrl;
  }

  /// Upload a client note file (PDF, image, doc) and return the download URL.
  Future<String> uploadClientNote(String uid, File file, String fileName) async =>
      uploadClientNoteBytes(uid, await file.readAsBytes(), fileName);

  Future<String> uploadClientNoteBytes(
      String uid, Uint8List bytes, String fileName) async {
    final ext = fileName.split('.').last.toLowerCase();
    final ref = _storage.ref().child('client_notes/$uid/$fileName');

    String contentType = 'application/octet-stream';
    if (ext == 'pdf') contentType = 'application/pdf';
    else if (['jpg', 'jpeg'].contains(ext)) contentType = 'image/jpeg';
    else if (ext == 'png') contentType = 'image/png';
    else if (ext == 'doc') contentType = 'application/msword';
    else if (ext == 'docx') contentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return await ref.getDownloadURL();
  }

  Future<String> createUser({
    required String username,
    required String password,
    required String fullName,
    required String role,
    String phone = '',
    String address = '',
    double? latitude,
    double? longitude,
    String emergencyContact = '',
    File? photo,
    File? noteFile,
    String noteFileName = '',
    Uint8List? photoBytes,
    Uint8List? noteBytes,
  }) async {
    final email = _usernameToEmail(username);

    // Check if username already exists
    final existing = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.toLowerCase().trim())
        .get();

    if (existing.docs.isNotEmpty) {
      throw FirebaseAuthException(
        code: 'username-exists',
        message: 'Username "$username" is already taken.',
      );
    }

    // Use a secondary app to create the user without logging out the admin
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = Firebase.app('userCreation');
    } catch (_) {
      secondaryApp = await Firebase.initializeApp(
        name: 'userCreation',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      // Upload photo if provided
      String photoUrl = '';
      final photoData = photoBytes ?? await photo?.readAsBytes();
      if (photoData != null) {
        photoUrl = await uploadProfilePhotoBytes(uid, photoData);
      }

      // Upload client note file if provided
      String clientNoteUrl = '';
      final noteData = noteBytes ?? await noteFile?.readAsBytes();
      if (noteData != null && noteFileName.isNotEmpty) {
        clientNoteUrl = await uploadClientNoteBytes(uid, noteData, noteFileName);
      }

      // Save user profile in Firestore
      final newUser = AppUser(
        uid: uid,
        username: username.toLowerCase().trim(),
        fullName: fullName,
        role: role,
        phone: phone,
        address: address,
        latitude: latitude,
        longitude: longitude,
        emergencyContact: emergencyContact,
        photoUrl: photoUrl,
        clientNoteUrl: clientNoteUrl,
        clientNoteFileName: noteFileName,
      );

      await _firestore.collection('users').doc(uid).set(newUser.toMap());

      // Sign out from secondary app
      await secondaryAuth.signOut();

      return uid;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  /// Create a family member account linked to a client
  Future<String> createFamilyMember({
    required String username,
    required String password,
    required String fullName,
    required String linkedClientId,
  }) async {
    final email = _usernameToEmail(username);

    // Check if username already exists
    final existing = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.toLowerCase().trim())
        .get();

    if (existing.docs.isNotEmpty) {
      throw FirebaseAuthException(
        code: 'username-exists',
        message: 'Username "$username" is already taken.',
      );
    }

    FirebaseApp? secondaryApp;
    try {
      secondaryApp = Firebase.app('userCreation');
    } catch (_) {
      secondaryApp = await Firebase.initializeApp(
        name: 'userCreation',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

    final credential = await secondaryAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;

    final familyUser = AppUser(
      uid: uid,
      username: username.toLowerCase().trim(),
      fullName: fullName,
      role: 'family',
      linkedClientId: linkedClientId,
    );

    await _firestore.collection('users').doc(uid).set(familyUser.toMap());

    // Add this family member's uid to the client's familyMemberIds
    await _firestore.collection('users').doc(linkedClientId).update({
      'familyMemberIds': FieldValue.arrayUnion([uid]),
    });

    await secondaryAuth.signOut();

    return uid;
  }

  /// Delete a family member account
  Future<void> deleteFamilyMember(String familyUid, String clientId) async {
    // Remove from client's familyMemberIds
    await _firestore.collection('users').doc(clientId).update({
      'familyMemberIds': FieldValue.arrayRemove([familyUid]),
    });

    // Delete storage files
    try {
      await _storage.ref().child('profile_photos/$familyUid.jpg').delete();
    } catch (_) {}

    // Delete Firestore doc
    await _firestore.collection('users').doc(familyUid).delete();

    // Best-effort Firebase Auth cleanup
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = Firebase.app('userCreation');
    } catch (_) {
      secondaryApp = await Firebase.initializeApp(
        name: 'userCreation',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      await secondaryAuth.currentUser?.delete();
      await secondaryAuth.signOut();
    } catch (_) {}
  }

  /// Get family members for a client
  Future<List<AppUser>> getFamilyMembers(String clientId) async {
    final doc = await _firestore.collection('users').doc(clientId).get();
    if (!doc.exists) return [];

    final data = doc.data() as Map<String, dynamic>;
    final memberIds = List<String>.from(data['familyMemberIds'] ?? []);
    if (memberIds.isEmpty) return [];

    final members = <AppUser>[];
    for (final id in memberIds) {
      final memberDoc = await _firestore.collection('users').doc(id).get();
      if (memberDoc.exists) {
        members.add(AppUser.fromFirestore(memberDoc));
      }
    }
    return members;
  }

  /// Toggle user active status
  Future<void> toggleUserActive(String uid, bool isActive) async {
    await _firestore.collection('users').doc(uid).update({
      'isActive': isActive,
    });
  }

  /// Soft-delete a user: deactivate their account, remove assignments, and
  /// clean up Storage files.  The Firestore doc is kept (with isActive=false)
  /// so that `signIn` and `getCurrentUser` can reliably block access.
  /// Firebase Auth records cannot be deleted from client-side without the
  /// user's password or Admin SDK, so we rely on the Firestore `isActive`
  /// flag as the single source of truth.
  Future<void> deleteUser(String uid, String username) async {
    // 1. Delete all assignments where this user is a caregiver
    final caregiverAssignments = await _firestore
        .collection('assignments')
        .where('caregiverId', isEqualTo: uid)
        .get();
    for (final doc in caregiverAssignments.docs) {
      await doc.reference.delete();
    }

    // 2. Delete all assignments where this user is a client
    final clientAssignments = await _firestore
        .collection('assignments')
        .where('clientId', isEqualTo: uid)
        .get();
    for (final doc in clientAssignments.docs) {
      await doc.reference.delete();
    }

    // 3. Delete Storage files (profile photo + client notes)
    try {
      await _storage.ref().child('profile_photos/$uid.jpg').delete();
    } catch (_) {}
    try {
      final notesRef = _storage.ref().child('client_notes/$uid');
      final notesList = await notesRef.listAll();
      for (final item in notesList.items) {
        await item.delete();
      }
    } catch (_) {}

    // 4. Soft-delete family members if this is a client
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      final familyIds = List<String>.from(userData['familyMemberIds'] ?? []);
      for (final familyId in familyIds) {
        try {
          await _firestore.collection('users').doc(familyId).update({
            'isActive': false,
            'deletedAt': FieldValue.serverTimestamp(),
            'photoUrl': '',
          });
          try {
            await _storage.ref().child('profile_photos/$familyId.jpg').delete();
          } catch (_) {}
        } catch (_) {}
      }
    }

    // 5. Soft-delete: mark user as inactive and clear sensitive data
    await _firestore.collection('users').doc(uid).update({
      'isActive': false,
      'deletedAt': FieldValue.serverTimestamp(),
      'photoUrl': '',
    });
  }

  /// Get users by role
  Stream<List<AppUser>> getUsersByRole(String role) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: role)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList());
  }

  /// Save FCM token to the user's Firestore document
  Future<void> saveFcmToken(String uid) async {
    // On iOS the APNS token can arrive a moment after launch; getToken()
    // throws until it's available. Wait briefly for it on real devices
    // (simulators never get one — caller treats the throw as non-fatal).
    if (Platform.isIOS) {
      String? apnsToken;
      for (var i = 0; i < 5 && apnsToken == null; i++) {
        apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      if (apnsToken == null) return; // simulator or APNS unavailable
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _firestore.collection('users').doc(uid).update({
        'fcmToken': token,
      });
    }
  }

  /// Remove FCM token from the user's Firestore document
  Future<void> removeFcmToken(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'fcmToken': FieldValue.delete(),
    });
  }

  /// Submit a password reset request (called from login screen).
  /// Validates the username exists and sets a flag in Firestore.
  /// Submit a password reset request (called from login screen).
  /// Uses a separate public 'password_reset_requests' collection since the
  /// user is not authenticated at this point.
  Future<void> requestPasswordReset(String username) async {
    // Accept both "mark" and "mark@megahomecare.app"
    var cleanUsername = username.toLowerCase().trim();
    if (cleanUsername.contains('@')) {
      cleanUsername = cleanUsername.split('@').first;
    }

    // We can't read the users collection (auth required), so we sign in
    // temporarily on a secondary app to validate the username and write
    // the reset flag.
    // Actually, we can't sign in without the password either.
    // Solution: use a public collection that allows unauthenticated writes.
    await _firestore.collection('password_reset_requests').add({
      'username': cleanUsername,
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  /// Change the signed-in user's own password. Firebase requires a recent
  /// sign-in, so the current password is checked first.
  Future<void> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Reset a user's password (admin action).
  /// Calls a Cloud Function that uses Firebase Admin SDK to update the password.
  Future<void> resetUserPassword({
    required String uid,
    required String newPassword,
  }) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('resetUserPassword');
    await callable.call({'uid': uid, 'newPassword': newPassword});
  }

  /// Clear password reset request (admin dismisses without resetting)
  Future<void> clearPasswordResetRequest(String username) async {
    final requests = await _firestore
        .collection('password_reset_requests')
        .where('username', isEqualTo: username.toLowerCase().trim())
        .where('status', isEqualTo: 'pending')
        .get();
    for (final doc in requests.docs) {
      await doc.reference.update({'status': 'dismissed'});
    }
  }

  /// Get all pending password reset requests
  Future<Set<String>> getPendingResetUsernames() async {
    final requests = await _firestore
        .collection('password_reset_requests')
        .where('status', isEqualTo: 'pending')
        .get();
    return requests.docs
        .map((d) => (d.data()['username'] as String?) ?? '')
        .where((u) => u.isNotEmpty)
        .toSet();
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Seed admin account (call once during first setup)
  Future<void> seedAdmin({
    required String username,
    required String password,
  }) async {
    final email = _usernameToEmail(username);

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      final admin = AppUser(
        uid: uid,
        username: username.toLowerCase().trim(),
        fullName: 'Administrator',
        role: 'admin',
      );

      await _firestore.collection('users').doc(uid).set(admin.toMap());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Admin already exists, just sign in
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return;
      }
      rethrow;
    }
  }
}
