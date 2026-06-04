import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/app_shell.dart';
import 'screens/auth_screen.dart';
import 'services/notification_navigation_service.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeSupabase();
  try {
    await Firebase.initializeApp();
    await NotificationService().initialize();
  } catch (_) {
    // Firebase platform files are added after the Flutter native projects exist.
  }
  runApp(const DownsviewApp());
}

class DownsviewApp extends StatefulWidget {
  const DownsviewApp({super.key});

  @override
  State<DownsviewApp> createState() => _DownsviewAppState();
}

class _DownsviewAppState extends State<DownsviewApp> {
  bool _guestMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Downsview SDA',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: StreamBuilder<AuthState>(
        stream: supabase.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = supabase.auth.currentSession;
          if (session?.user != null || _guestMode) {
            return AppShell(
              isGuest: session?.user == null,
              onSignInPress: () => setState(() => _guestMode = false),
            );
          }

          return AuthScreen(
            onContinueAsGuest: () => setState(() => _guestMode = true),
          );
        },
      ),
    );
  }
}
