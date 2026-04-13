import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'screens/splash_screen.dart';
import 'screens/home_page.dart';
import 'screens/create_profile.dart';
import 'screens/admin/admin_overview_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.initialize();
  unawaited(DatabaseHelper.performAutoBackup());
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  await PushNotificationService.initialize();
  if (kDebugMode) {
    try {
      await FirestoreService().uploadHomeMockDataIfEmpty();
      await FirestoreService.seedCoursesIfEmpty();
      await FirestoreService.seedJobsIfEmpty();
      await FirestoreService.seedJobsUpsert();
    } catch (_) {
      // Do not crash if seed fails (e.g. Firestore rules before sign-in).
    }
  }
  runApp(const MyApp());
}

/// True if [user] has Auth custom claim `admin` or an `admins/{uid}` document (before token refresh).
Future<bool> _isCurrentUserAdmin(User user) async {
  try {
    final token = await user.getIdTokenResult(true);
    if (token.claims?['admin'] == true) return true;
    final adminsSnap = await FirebaseFirestore.instance
        .collection('admins')
        .doc(user.uid)
        .get();
    return adminsSnap.exists;
  } catch (_) {
    return false;
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
          // Not signed in → Splash
          if (!snapshot.hasData) {
            return const SplashScreen();
          }

          final user = snapshot.data;

          if (user == null) {
            return const SplashScreen();
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
    return _ProfileGateData(isAdmin: isAdmin, uid: user.uid);
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
        if (gate.isAdmin) {
          return const AdminOverviewScreen();
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(AppConstants.collectionUsers)
              .doc(gate.uid)
              .snapshots(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (profileSnapshot.hasError) {
              return _profileLoadErrorScaffold();
            }
            final profileSnap = profileSnapshot.data;
            if (profileSnap == null || !profileSnap.exists) {
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
      },
    );
  }
}

class _ProfileGateData {
  final bool isAdmin;
  final String uid;

  const _ProfileGateData({required this.isAdmin, required this.uid});

  factory _ProfileGateData.error() =>
      const _ProfileGateData(isAdmin: false, uid: '');
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
