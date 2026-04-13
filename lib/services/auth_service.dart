import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/google_sign_in_config.dart';

/// Firebase Authentication helpers: email/password is used from screens;
/// Google Sign-In and unified sign-out live here.
class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Logs Firebase app + current platform options (no secrets). Use when debugging Auth email flows.
  static void debugLogFirebaseConfig(String _) {}

  static String? get _googleServerClientId {
    const fromEnv = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kGoogleOAuthWebClientId.trim().isNotEmpty) {
      return kGoogleOAuthWebClientId.trim();
    }
    return null;
  }

  static GoogleSignIn _googleSignIn() => GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: _googleServerClientId,
      );

  /// Signs in with Google and ensures a Firestore `users/{uid}` document exists.
  static Future<UserCredential> signInWithGoogle() async {
    final googleSignIn = _googleSignIn();

    final GoogleSignInAccount? account = await googleSignIn.signIn();
    if (account == null) {
      throw GoogleSignInCanceledException();
    }

    final GoogleSignInAuthentication googleAuth = await account.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    await ensureUserDocument(userCred.user);
    return userCred;
  }

  /// Creates or merges profile fields for the signed-in [user] (e.g. after Google).
  static Future<void> ensureUserDocument(User? user) async {
    if (user == null) return;
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'email': user.email,
        'name': user.displayName ?? '',
        'full_name': user.displayName ?? '',
        'profile_completed': false,
        'skills': <dynamic>[],
        'photoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final data = snap.data();
    final updates = <String, dynamic>{
      'email': user.email ?? data?['email'],
    };
    final fullName = data?['full_name']?.toString().trim();
    if (fullName == null || fullName.isEmpty) {
      final dn = user.displayName?.trim();
      if (dn != null && dn.isNotEmpty) {
        updates['full_name'] = dn;
      }
    }
    final photo = data?['photoUrl']?.toString().trim();
    if ((photo == null || photo.isEmpty) &&
        user.photoURL != null &&
        user.photoURL!.isNotEmpty) {
      updates['photoUrl'] = user.photoURL;
    }
    if (updates.length > 1 || updates['email'] != null) {
      await ref.set(updates, SetOptions(merge: true));
    }
  }

  /// Signs out of Firebase and Google (so account picker shows next time).
  static Future<void> signOut() async {
    try {
      await _googleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  /// Password reset: verifies email/password registration, then sends reset mail with [ActionCodeSettings].
  /// Returns `false` if email is not registered for password auth or on error. Logs details in debug mode.
  static Future<bool> resetPassword(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    try {
      final methods = await _auth.fetchSignInMethodsForEmail(trimmed);

      if (methods.isEmpty) {
        return false;
      }

      const emailPassword = 'password';
      if (!methods.contains(emailPassword)) {
        return false;
      }

      final actionCodeSettings = ActionCodeSettings(
        url: 'https://gradready.page.link/reset',
        handleCodeInApp: true,
        androidPackageName: 'com.example.grad_ready',
        androidInstallApp: true,
        androidMinimumVersion: '21',
        iOSBundleId: 'com.example.gradReady',
      );

      await _auth.sendPasswordResetEmail(
        email: trimmed,
        actionCodeSettings: actionCodeSettings,
      );
      return true;
    } on FirebaseAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// **Debug only:** sends reset email **without** [ActionCodeSettings] to isolate template/delivery issues.
  /// Watch console for `=== EMAIL TEST ===` lines. Uses same [email] field as login.
  static Future<void> testResetEmail(String email) async {
    try {
      await FirebaseAuth.instance.fetchSignInMethodsForEmail(email.trim());

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
    } catch (_) {
      // Ignore debug helper failures.
    }
  }

  /// Alias for [testResetEmail] (temporary debug).
  static Future<void> sendTestResetEmail(String email) => testResetEmail(email);
}

/// Thrown when the user closes the Google account picker without selecting an account.
class GoogleSignInCanceledException implements Exception {
  @override
  String toString() => 'GoogleSignInCanceledException';
}
