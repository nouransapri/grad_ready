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
  if (kDebugMode) {
    await FirestoreService().uploadHomeMockDataIfEmpty();
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
          // لو المستخدم مش مسجل دخول → Splash
          if (!snapshot.hasData) {
            return const SplashScreen();
          }

          final user = snapshot.data;

          if (user == null) {
            return const SplashScreen();
          }

          // لو مسجل دخول → نشيك profile_completed في Firestore
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

  @override
  void initState() {
    super.initState();
    _profileFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .get();
  }

  void _retry() {
    setState(() {
      _profileFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();
    });
  }

  static bool _isAdminEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    final e = email.trim().toLowerCase();
    return e == 'admin@gradready' || e == 'admin@gradready.com';
  }

  Future<void> _createAdminDocAndRefresh() async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .set({
          'uid': widget.user.uid,
          'email': widget.user.email,
          'role': 'admin',
          'profile_completed': true,
          'created_at': FieldValue.serverTimestamp(),
        });
    if (!mounted) return;
    setState(() {
      _profileFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();
    });
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

        // لا يوجد مستند مستخدم: إنشاء مستند أدمن إذا كان الإيميل أدمن
        if (profileSnapshot.hasData &&
            !profileSnapshot.data!.exists &&
            _isAdminEmail(widget.user.email)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _createAdminDocAndRefresh();
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return const CreateProfileScreen();
      },
    );
  }
}
