import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/home_page.dart';
import 'screens/create_profile.dart'; // تأكدي إن المسار صح

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GradReady',
      debugShowCheckedModeBanner: false,
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
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (profileSnapshot.hasError) {
                return const Scaffold(
                  body: Center(
                    child: Text("Error loading profile"),
                  ),
                );
              }

              if (profileSnapshot.hasData &&
                  profileSnapshot.data!.exists) {
                final data =
                    profileSnapshot.data!.data() as Map<String, dynamic>;

                final completed = data['profile_completed'] ?? false;

                if (completed == true) {
                  return const HomePage();
                } else {
                  return const CreateProfileScreen();
                }
              }

              // لو مفيش document خالص → يروح Create Profile
              return const CreateProfileScreen();
            },
          );
        },
      ),
    );
  }
}