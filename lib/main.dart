import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // أضفنا المكتبة دي للتحقق من المستخدم
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/home_page.dart'; // تأكدي إن ملف الـ HomePage موجود في فولدر screens

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
      // الـ StreamBuilder هو اللي بيراقب حالة المستخدم لحظياً
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // لو الـ snapshot فيه بيانات (Data)، يبقى المستخدم مسجل دخول وجاهز
          if (snapshot.hasData) {
            return const HomePage();
          }
          // لو مفيش بيانات (مستخدم جديد أو عامل Logout)، يوديه للـ Splash
          return const SplashScreen();
        },
      ),
    );
  }
}