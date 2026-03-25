import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_theme.dart';
// Generate firebase_options.dart by running: flutterfire configure
import 'firebase_options.dart';
import 'services/firestore_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_page.dart';
import 'screens/create_profile.dart';
import 'screens/admin/admin_overview_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  if (kDebugMode) {
    try {
      await FirestoreService().uploadHomeMockDataIfEmpty();
      await FirestoreService.seedCoursesIfEmpty();
      await FirestoreService.seedJobsIfEmpty();
      await FirestoreService.seedJobsUpsert();
      debugPrint('Jobs seed completed successfully');
    } catch (e, st) {
      // Do not crash if seed fails (e.g. Firestore rules before sign-in).
      debugPrint('Debug seed/mock data skipped: $e');
      if (kDebugMode) debugPrintStack(stackTrace: st);
    }
  }
  runApp(const MyApp());
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

/// Loads user profile from Firestore and routes to Home or CreateProfile. Supports retry on error.
class _ProfileGate extends StatefulWidget {
  final User user;

  const _ProfileGate({required this.user});

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late Future<DocumentSnapshot> _profileFuture;
  late Future<bool> _isAdminFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .get();
    _isAdminFuture = _isAdminUser();
  }

  void _retry() {
    setState(() {
      _profileFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();
      _isAdminFuture = _isAdminUser();
    });
  }

  Future<bool> _isAdminUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final token = await user.getIdTokenResult(true);
      return token.claims?['admin'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _profileFuture,
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (profileSnapshot.hasError) {
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

        if (profileSnapshot.hasData && profileSnapshot.data!.exists) {
          final data = profileSnapshot.data!.data() as Map<String, dynamic>;
          if (data['role'] == 'admin') {
            return const AdminOverviewScreen();
          }
          final completed = data['profile_completed'] ?? false;
          if (completed == true) {
            return const HomePage();
          }
          return const CreateProfileScreen();
        }

        if (profileSnapshot.hasData && !profileSnapshot.data!.exists) {
          return FutureBuilder<bool>(
            future: _isAdminFuture,
            builder: (context, adminSnapshot) {
              if (adminSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (adminSnapshot.data == true) {
                return const AdminOverviewScreen();
              }
              return const CreateProfileScreen();
            },
          );
        }

        return const CreateProfileScreen();
      },
    );
  }
}
