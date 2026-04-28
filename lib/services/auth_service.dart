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

  // ---------------------------------------------------------------------------
  // Gatekeeper: check isSuspended after successful Firebase Auth
  // ---------------------------------------------------------------------------

  /// Checks whether the authenticated user is suspended in Firestore.
  /// If `isSuspended == true`, signs the user out immediately and throws
  /// [AccountDeactivatedException].
  static Future<void> _enforceActiveStatus(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 8));

      final data = doc.data();
      if (data != null && data['isSuspended'] == true) {
        await _auth.signOut();
        throw AccountDeactivatedException();
      }
    } on AccountDeactivatedException {
      rethrow;
    } catch (_) {
      // If the Firestore fetch fails (network, permissions, etc.) we allow
      // login to proceed rather than locking users out due to transient errors.
    }
  }

  // ---------------------------------------------------------------------------
  // Email / Password sign-in
  // ---------------------------------------------------------------------------

  /// Signs in with email & password, then enforces the active-status gatekeeper.
  /// Throws [AccountDeactivatedException] if the account is suspended.
  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final userCred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCred.user;
    if (user != null) {
      await _enforceActiveStatus(user);
    }

    return userCred;
  }

  // ---------------------------------------------------------------------------
  // Google sign-in
  // ---------------------------------------------------------------------------

  /// Signs in with Google and ensures a Firestore `users/{uid}` document exists.
  /// Throws [AccountDeactivatedException] if the account is suspended.
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

    // Gatekeeper: block suspended users even via Google sign-in.
    final user = userCred.user;
    if (user != null) {
      await _enforceActiveStatus(user);
    }

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

  /// Password reset: checks the user's auth provider before sending a reset email.
  ///
  /// - **Google-only accounts** → throws [PasswordResetException] telling the
  ///   user to sign in with Google.
  /// - **Email/password accounts** → sends a reset email via Firebase.
  /// - **Unknown email** → throws [PasswordResetException] saying no account found.
  ///
  /// On success the method completes normally; all error paths throw.
  static Future<void> resetPassword(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw PasswordResetException('Please enter a valid email address.');
    }

    try {
      // ignore: deprecated_member_use
      final methods = await _auth.fetchSignInMethodsForEmail(trimmed);

      if (methods.isEmpty) {
        // Case C – no account registered with this email.
        throw PasswordResetException(
          'No account found with this email.',
        );
      }

      if (methods.contains('google.com') && !methods.contains('password')) {
        // Case A – Google-only user; no password to reset.
        throw PasswordResetException(
          'This account is linked with Google. '
          'Please sign in directly using the Google button.',
        );
      }

      // Case B – email/password user (may also have Google linked).
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
    } on PasswordResetException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') {
        throw PasswordResetException('Invalid email address.');
      }
      // For other Firebase errors (user-not-found when enumeration is off, etc.)
      // surface a generic but helpful message.
      throw PasswordResetException(
        'Unable to process request. Please try again later.',
      );
    } catch (_) {
      throw PasswordResetException(
        'Something went wrong. Please try again.',
      );
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

/// Thrown when a user whose Firestore document has `isSuspended: true` attempts to sign in.
class AccountDeactivatedException implements Exception {
  final String message;
  const AccountDeactivatedException([
    this.message = 'This account has been deactivated. Please contact support.',
  ]);

  @override
  String toString() => message;
}

/// Thrown by [AuthService.resetPassword] to carry a user-facing message
/// describing why the reset could not proceed.
class PasswordResetException implements Exception {
  final String message;
  const PasswordResetException(this.message);

  @override
  String toString() => message;
}
