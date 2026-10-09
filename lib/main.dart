import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'views/login_screen.dart';
import 'views/admin/admin_dashboard.dart';
import 'views/caregiver/caregiver_dashboard.dart';
import 'views/client/client_dashboard.dart';
import 'views/family/family_dashboard.dart';
import 'web/admin_web_shell.dart';
import 'web/apply/apply_page.dart';
import 'web/web_login_screen.dart';
import 'widgets/incoming_call_listener.dart';

/// Local web testing only: `--dart-define=USE_EMULATORS=true` points the web
/// build at the Firebase emulators (project demo-mega) instead of production.
/// Not for Android: its default app is set up natively from
/// google-services.json, so the demo project id doesn't take effect there.
const _useEmulators = bool.fromEnvironment('USE_EMULATORS');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // .env holds mobile secrets (Agora App ID, Maps key). The web admin never
  // loads it; its Maps key comes from --dart-define-from-file=.env.web.
  if (!kIsWeb) await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(
    options: _useEmulators
        ? DefaultFirebaseOptions.currentPlatform.copyWith(projectId: 'demo-mega')
        : DefaultFirebaseOptions.currentPlatform,
  );

  // FCM background handler must be registered before runApp
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Enable Firestore offline persistence for offline message queuing.
  // Not on web: the admin panel is always online, and the IndexedDB cache
  // delays the first reads by several seconds.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: !kIsWeb,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  if (_useEmulators) {
    FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8085);
    FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5001);
    await FirebaseStorage.instance.useStorageEmulator('127.0.0.1', 9199);
  }

  // Push and call notifications are mobile-only; the web build is the
  // admin panel.
  if (!kIsWeb) await NotificationService().initialize();

  runApp(const MegaHomeCareApp());
}

/// Token from a caregiver application link (`mega-h.web.app/apply/<token>`),
/// or null. Those links open the public application page instead of the
/// admin panel, with no login.
String? get applyLinkToken {
  if (!kIsWeb) return null;
  final segments = Uri.base.pathSegments;
  return segments.length >= 2 && segments[0] == 'apply' && segments[1].isNotEmpty
      ? segments[1]
      : null;
}

class MegaHomeCareApp extends StatelessWidget {
  const MegaHomeCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final applyToken = applyLinkToken;
    if (applyToken != null) {
      return GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: MaterialApp(
          title: 'Mega Homecare – Application',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          home: ApplyPage(token: applyToken),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => AuthViewModel()..init(),
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: MaterialApp(
          title: kIsWeb ? 'Mega Homecare Admin' : 'Mega Homecare Inc',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          home: const AuthGate(),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();

    if (authVm.isInitializing) {
      return const _SplashScreen();
    }

    if (authVm.currentUser == null) {
      return kIsWeb ? const WebLoginScreen() : const LoginScreen();
    }

    final user = authVm.currentUser!;

    if (kIsWeb) {
      return user.role == 'admin'
          ? const AdminWebShell()
          : const WebAdminOnlyScreen();
    }

    Widget dashboard;
    switch (user.role) {
      case 'admin':
        dashboard = const AdminDashboard();
      case 'caregiver':
        dashboard = const CaregiverDashboard();
      case 'client':
        dashboard = const ClientDashboard();
      case 'family':
        dashboard = const FamilyDashboard();
      default:
        return const LoginScreen();
    }

    return IncomingCallListener(
      currentUser: user,
      child: dashboard,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.asset(
                  'assets/app_icon.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Mega Homecare Inc',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Quality Care at Home',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.primaryColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
