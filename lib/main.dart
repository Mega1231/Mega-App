import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'web/web_login_screen.dart';
import 'widgets/incoming_call_listener.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // .env holds mobile secrets (Agora App ID, Maps key). The web admin never
  // loads it; its Maps key comes from --dart-define-from-file=.env.web.
  if (!kIsWeb) await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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

  // Push and call notifications are mobile-only; the web build is the
  // admin panel.
  if (!kIsWeb) await NotificationService().initialize();

  runApp(const MegaHomeCareApp());
}

class MegaHomeCareApp extends StatelessWidget {
  const MegaHomeCareApp({super.key});

  @override
  Widget build(BuildContext context) {
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
