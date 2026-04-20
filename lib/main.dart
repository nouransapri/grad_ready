import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app_theme.dart';
// Generate firebase_options.dart by running: flutterfire configure
import 'firebase_options.dart';
import 'firebase_messaging_background.dart';
import 'services/database_helper.dart';
import 'services/firestore_service.dart';
import 'services/hive_service.dart';
import 'services/push_notification_service.dart';
import 'services/auth_service.dart';
import 'utils/constants.dart';
import 'screens/login_screen.dart';
import 'screens/home_page.dart';
import 'screens/create_profile.dart';
import 'screens/admin/admin_overview_screen.dart';

/// Paints [runApp] immediately so the **native** splash (flutter_native_splash) is replaced
/// by a Flutter frame. Firebase/Hive init runs **after** that — otherwise `await
/// Firebase.initializeApp()` can block indefinitely offline and the logo screen never leaves.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runZonedGuarded(
    () => runApp(const _GradReadyBootstrap()),
    (error, stack) {
      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } catch (_) {
        debugPrint('Zone error (Crashlytics not ready): $error\n$stack');
      }
    },
  );
}

class _GradReadyBootstrap extends StatefulWidget {
  const _GradReadyBootstrap();

  @override
  State<_GradReadyBootstrap> createState() => _GradReadyBootstrapState();
}

class _GradReadyBootstrapState extends State<_GradReadyBootstrap> {
  bool _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _warmStart();
  }

  Future<void> _warmStart() async {
    if (mounted) {
      setState(() => _error = null);
    }
    try {
      await HiveService.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('HiveService.initialize'),
      );
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw TimeoutException(
          'Firebase.initializeApp exceeded 25s (often offline / Play Services).',
        ),
      );
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      }
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      unawaited(DatabaseHelper.performAutoBackup());
      unawaited(
        Future<void>(() async {
          try {
            await PushNotificationService.initialize();
          } catch (_) {}
        }),
      );
      if (kDebugMode) {
        unawaited(
          Future<void>(() async {
            try {
              await FirestoreService().uploadHomeMockDataIfEmpty();
              await FirestoreService.seedCoursesIfEmpty();
              await FirestoreService.seedJobsIfEmpty();
              await FirestoreService.seedJobsUpsert();
            } catch (_) {}
          }),
        );
      }
      if (mounted) setState(() => _ready = true);
    } catch (e, st) {
      try {
        FirebaseCrashlytics.instance.recordError(e, st, fatal: false);
      } catch (_) {}
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey.shade700),
                  const SizedBox(height: 16),
                  Text(
                    'تعذّر تهيئة التطبيق. تحقّق من الإنترنت ثم أعد المحاولة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _warmStart,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    return const MyApp();
  }
}

/// True if [user] has Auth custom claim `admin` or an `admins/{uid}` document.
/// Uses cached ID token ([getIdTokenResult(false)]) so startup does not wait on the network
/// when the device is offline (force-refresh would block or time out).
Future<bool> _isCurrentUserAdmin(User user) async {
  try {
    final token =
        await user.getIdTokenResult(false).timeout(const Duration(seconds: 8));
    if (token.claims?['admin'] == true) return true;
    // Prefer cache offline; default get() can wait on the server.
    final adminsSnap = await FirebaseFirestore.instance
        .collection('admins')
        .doc(user.uid)
        .get(const GetOptions(source: Source.serverAndCache))
        .timeout(const Duration(seconds: 8));
    return adminsSnap.exists;
  } catch (_) {
    try {
      final adminsSnap = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get(const GetOptions(source: Source.cache));
      return adminsSnap.exists;
    } catch (_) {
      return false;
    }
  }
}

/// Resolves `users/{uid}` without hanging offline: cache first, then bounded server read.
Future<DocumentSnapshot<Map<String, dynamic>>> _userProfileSnapshotOnce(
  String uid,
) async {
  final ref = FirebaseFirestore.instance
      .collection(AppConstants.collectionUsers)
      .doc(uid);
  try {
    final cached = await ref.get(const GetOptions(source: Source.cache));
    if (cached.exists) return cached;
  } catch (_) {}
  try {
    return await ref
        .get(const GetOptions(source: Source.serverAndCache))
        .timeout(const Duration(seconds: 12));
  } on TimeoutException {
    return ref.get(const GetOptions(source: Source.cache));
  } catch (_) {
    return ref.get(const GetOptions(source: Source.cache));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GradReady',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Not signed in → Login
          if (!snapshot.hasData) {
            return const LoginScreen();
          }

          final user = snapshot.data;

          if (user == null) {
            return const LoginScreen();
          }

          // Signed in → check profile_completed in Firestore
          return _ProfileGate(user: user);
        },
      ),
    );
  }
}

/// Loads admin status (claims or admins/{uid}) + user profile. Never trusts users.role.
class _ProfileGate extends StatefulWidget {
  final User user;

  const _ProfileGate({required this.user});

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late Future<_ProfileGateData> _gateFuture;

  @override
  void initState() {
    super.initState();
    _gateFuture = _loadProfileGate();
  }

  void _retry() {
    setState(() {
      _gateFuture = _loadProfileGate();
    });
  }

  Widget _profileLoadErrorScaffold() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 16),
              Text(
                "Couldn't load your profile",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<_ProfileGateData> _loadProfileGate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _ProfileGateData.error();
    }
    final isAdmin = await _isCurrentUserAdmin(user);
    if (isAdmin) {
      return _ProfileGateData.admin(uid: user.uid);
    }
    try {
      final profileSnap = await _userProfileSnapshotOnce(user.uid);
      return _ProfileGateData.member(uid: user.uid, profileSnap: profileSnap);
    } catch (_) {
      return _ProfileGateData.error();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProfileGateData>(
      future: _gateFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _profileLoadErrorScaffold();
        }

        final gate = snapshot.data!;
        if (gate.uid.isEmpty) {
          return _profileLoadErrorScaffold();
        }
        if (gate.isAdmin) {
          return const AdminOverviewScreen();
        }
        final profileSnap = gate.profileSnap;
        if (profileSnap == null) {
          return _profileLoadErrorScaffold();
        }
        if (!profileSnap.exists) {
          return const CreateProfileScreen();
        }
        final data = profileSnap.data();
        if (data?[AppConstants.userFieldIsSuspended] == true) {
          return const _SuspendedAccountScreen();
        }
        final completed = data?['profile_completed'] ?? false;
        if (completed == true) {
          return const HomePage();
        }
        return const CreateProfileScreen();
      },
    );
  }
}

class _ProfileGateData {
  final bool isAdmin;
  final String uid;
  /// Loaded for non-admin flow (cache-first + timeout; avoids [snapshots] stuck offline).
  final DocumentSnapshot<Map<String, dynamic>>? profileSnap;

  const _ProfileGateData({
    required this.isAdmin,
    required this.uid,
    this.profileSnap,
  });

  factory _ProfileGateData.admin({required String uid}) =>
      _ProfileGateData(isAdmin: true, uid: uid, profileSnap: null);

  factory _ProfileGateData.member({
    required String uid,
    required DocumentSnapshot<Map<String, dynamic>> profileSnap,
  }) =>
      _ProfileGateData(isAdmin: false, uid: uid, profileSnap: profileSnap);

  factory _ProfileGateData.error() => const _ProfileGateData(
        isAdmin: false,
        uid: '',
        profileSnap: null,
      );
}

class _SuspendedAccountScreen extends StatelessWidget {
  const _SuspendedAccountScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block_rounded, size: 52, color: Colors.red.shade400),
              const SizedBox(height: 12),
              const Text(
                'Your account is suspended.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Please contact support for assistance.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  await AuthService.signOut();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
