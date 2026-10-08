import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/caregiver_application.dart';

/// Thrown when a documents call needs the vault password (again).
class VaultLockedException implements Exception {
  const VaultLockedException();
}

/// Talks to the application Cloud Functions. Applicant calls carry the link
/// token; admin calls run as the signed-in admin.
class ApplicationService {
  final FirebaseFunctions _functions;

  ApplicationService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  /// Short-lived token from [unlockVault] / [setVaultPassword], kept for the
  /// browser session so Becky enters the documents password once per 30 min.
  static String? vaultToken;

  Future<dynamic> _call(
    String name,
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final result = await _functions
        .httpsCallable(name, options: HttpsCallableOptions(timeout: timeout))
        .call(data);
    return result.data;
  }

  /// A readable message for a failed call.
  static String errorText(Object e) {
    if (e is FirebaseFunctionsException) {
      return e.message ?? 'Something went wrong. Please try again.';
    }
    return 'Something went wrong. Please check your connection and try again.';
  }

  // ── Applicant ──

  Future<ApplicantApplication> load(String token) async =>
      ApplicantApplication.fromMap(
        await _call('applicationGet', {'token': token}),
      );

  Future<ApplicantApplication> saveDetails(
    String token,
    ApplicantDetails details,
  ) async => ApplicantApplication.fromMap(
    await _call('applicationSaveDetails', {
      'token': token,
      'details': details.toMap(),
    }),
  );

  Future<ApplicantApplication> upload(
    String token, {
    required String docType,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async => ApplicantApplication.fromMap(
    await _call('applicationUpload', {
      'token': token,
      'docType': docType,
      'fileName': fileName,
      'contentType': contentType,
      'data': base64Encode(bytes),
    }, timeout: const Duration(minutes: 2)),
  );

  Future<ApplicantApplication> submit(String token) async =>
      ApplicantApplication.fromMap(
        await _call('applicationSubmit', {'token': token}),
      );

  // ── Admin ──

  /// Returns the new application's id, link and whether the invite email
  /// went out.
  Future<({String id, String link, bool emailSent})> create({
    required String fullName,
    required String email,
    required bool sendEmail,
  }) async {
    final r = Map<String, dynamic>.from(
      await _call('applicationCreate', {
        'fullName': fullName,
        'email': email,
        'sendEmail': sendEmail,
      }),
    );
    return (
      id: r['id'] as String,
      link: r['link'] as String,
      emailSent: r['emailSent'] == true,
    );
  }

  Future<List<ApplicationSummary>> list() async =>
      ((await _call('applicationList', {})) as List)
          .map(ApplicationSummary.fromMap)
          .toList();

  Future<ApplicationRecord> get(String id) async =>
      ApplicationRecord.fromMap(await _call('applicationGetAdmin', {'id': id}));

  Future<ApplicationRecord> update(
    ApplicationRecord app, {
    String? fullName,
    String? email,
    bool? remindersOff,
  }) async => ApplicationRecord.fromMap(
    await _call('applicationUpdate', {
      'id': app.id,
      'fullName': ?fullName,
      'email': ?email,
      'remindersOff': ?remindersOff,
    }),
    fallbackDocuments: app.requiredDocuments,
  );

  /// [decision]: approved, needs_changes or uploaded (clears the review).
  Future<ApplicationRecord> reviewDocument(
    ApplicationRecord app, {
    required String docType,
    required String decision,
    String comment = '',
  }) async => ApplicationRecord.fromMap(
    await _call('applicationReviewDocument', {
      'id': app.id,
      'docType': docType,
      'decision': decision,
      'comment': comment,
    }),
    fallbackDocuments: app.requiredDocuments,
  );

  /// [decision]: accept, reject, reopen or request_changes.
  Future<({ApplicationRecord app, bool emailSent})> decide(
    ApplicationRecord app, {
    required String decision,
    String comment = '',
  }) async {
    final r = Map<String, dynamic>.from(
      await _call('applicationDecide', {
        'id': app.id,
        'decision': decision,
        'comment': comment,
      }),
    );
    return (
      app: ApplicationRecord.fromMap(
        r,
        fallbackDocuments: app.requiredDocuments,
      ),
      emailSent: r['emailSent'] == true,
    );
  }

  Future<({String link, bool emailSent})> regenerateLink(
    String id, {
    required bool sendEmail,
  }) async {
    final r = Map<String, dynamic>.from(
      await _call('applicationRegenerateLink', {
        'id': id,
        'sendEmail': sendEmail,
      }),
    );
    return (link: r['link'] as String, emailSent: r['emailSent'] == true);
  }

  Future<bool> sendEmailNow(String id) async {
    final r = Map<String, dynamic>.from(
      await _call('applicationSendEmail', {'id': id}),
    );
    return r['emailSent'] == true;
  }

  Future<void> delete(String id) => _call('applicationDelete', {'id': id});

  // ── Documents vault ──

  Future<bool> vaultIsSet() async =>
      Map<String, dynamic>.from(await _call('vaultStatus', {}))['isSet'] ==
      true;

  Future<void> unlockVault(String password) async {
    final r = Map<String, dynamic>.from(
      await _call('vaultUnlock', {'password': password}),
    );
    vaultToken = r['vaultToken'] as String;
  }

  /// First set, change (with [currentPassword]) or reset (right after the
  /// admin signed in again).
  Future<void> setVaultPassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    final r = Map<String, dynamic>.from(
      await _call('vaultSetPassword', {
        'currentPassword': ?currentPassword,
        'newPassword': newPassword,
      }),
    );
    vaultToken = r['vaultToken'] as String;
  }

  /// Downloads one uploaded file. Throws [VaultLockedException] when the
  /// vault needs unlocking.
  Future<({String fileName, String contentType, Uint8List bytes})> getDocument(
    String id,
    String docType, {
    String? storagePath,
  }) async {
    if (vaultToken == null) throw const VaultLockedException();
    try {
      final r = Map<String, dynamic>.from(
        await _call('applicationGetDocument', {
          'id': id,
          'docType': docType,
          'vaultToken': vaultToken,
          'storagePath': ?storagePath,
        }, timeout: const Duration(minutes: 2)),
      );
      return (
        fileName: r['fileName'] as String,
        contentType: r['contentType'] as String,
        bytes: base64Decode(r['data'] as String),
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.message == 'vault-locked') {
        vaultToken = null;
        throw const VaultLockedException();
      }
      rethrow;
    }
  }
}
