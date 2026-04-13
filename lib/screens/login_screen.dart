import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'create_account.dart';
import 'home_page.dart';
import 'create_profile.dart';
import 'admin/admin_overview_screen.dart';
import '../widgets/password_reset_dialog.dart';
import '../services/auth_service.dart';

const Color _gradientTop = Color(0xFF2A6CFF);
const Color _gradientBottom = Color(0xFF9226FF);
const Color _accentBlue = Color(0xFF2A6CFF);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _emailLoading = false;
  bool _googleLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

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

  Future<void> _goAfterLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    final isAdmin = await _isCurrentUserAdmin(user);
    if (!mounted) return;
    if (isAdmin) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminOverviewScreen()),
        (_) => false,
      );
      return;
    }
    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!mounted) return;
    final completed = profile.data()?['profile_completed'] == true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => completed ? const HomePage() : const CreateProfileScreen(),
      ),
      (_) => false,
    );
  }

  // Firebase sign-in
  Future<void> _login() async {
    if (_emailLoading || _googleLoading) return;
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      _showError('Please fix the highlighted fields.');
      return;
    }

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    setState(() => _emailLoading = true);
    try {
      final methods = await FirebaseAuth.instance
          .fetchSignInMethodsForEmail(email)
          .timeout(const Duration(seconds: 10));
      if (methods.isEmpty) {
        _showError('No account found for this email.');
        return;
      }
      if (!methods.contains('password')) {
        _showError('This account uses Google sign-in. Please continue with Google.');
        return;
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;
      await _goAfterLogin();
    } on TimeoutException {
      if (!mounted) return;
      _showError('Connection timeout. Check internet and try again.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = "Login Failed";
      if (e.code == 'user-not-found') {
        message = "No user found for that email.";
      } else if (e.code == 'wrong-password') {
        message = "Wrong password provided.";
      } else if (e.code == 'invalid-credential') {
        message = 'Invalid email or password.';
      } else if (e.code == 'network-request-failed') {
        message = 'Network error. Please check internet connection.';
      } else {
        message = e.message ?? "An error occurred";
      }

      _showError(message);
    } catch (_) {
      if (!mounted) return;
      _showError('Unexpected issue. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _emailLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _signInWithGoogle() async {
    if (_googleLoading) return;
    setState(() => _googleLoading = true);
    try {
      await AuthService.signInWithGoogle();
      if (!mounted) return;
      await _goAfterLogin();
    } on GoogleSignInCanceledException {
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      _showError(
        e is FirebaseAuthException
            ? (e.message ?? 'Google sign-in failed')
            : 'Google sign-in failed. Check SHA-1 / Web client ID in Firebase.',
      );
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _showPasswordResetDialog() async {
    final sent = await showDialog<bool?>(
      context: context,
      builder: (_) => PasswordResetDialog(initialEmail: emailController.text),
    );
    if (!mounted) return;
    if (sent == true) {
      _showSuccess(
        'If this email is registered, check your inbox and spam for a reset link.',
      );
    } else if (sent == false) {
      _showError(
        'Email not registered for password sign-in. Use a registered email or continue with Google.',
      );
    }
  }

  /// Debug-only: plain [sendPasswordResetEmail] + console logs (see [AuthService.testResetEmail]).
  Future<void> _testFirebaseEmail() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _showError('Enter an email in the field above, then tap Test Firebase Email.');
      return;
    }
    await AuthService.sendTestResetEmail(email);
    if (!mounted) return;
    _showSuccess(
      'Check debug console for === EMAIL TEST === / projectId / sign-in methods. '
      'If inbox is empty, verify Firebase Email/Password, templates, authorized domains, spam.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_gradientTop, _gradientBottom],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 40),

                        /// LOGO
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: SvgPicture.asset(
                              'assets/logo.svg',
                              width: 114,
                              height: 114,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'GradReady',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Turning Gaps into Growth',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),

                        const Spacer(),

                        /// Login Card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  30,
                                  24,
                                  30,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Login',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 25),
                                    Form(
                                      key: _formKey,
                                      child: Column(
                                        children: [
                                          _buildTextField(
                                            emailController,
                                            'Email',
                                            Icons.mail_outline,
                                          ),
                                          const SizedBox(height: 18),
                                          _buildTextField(
                                            passwordController,
                                            'Password',
                                            Icons.lock_outline,
                                            isPass: true,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 25),
                                    ElevatedButton(
                                      onPressed: _emailLoading ? null : _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: _accentBlue,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 15,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: _emailLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                              ),
                                            )
                                          : const Text(
                                              'Login',
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: _showPasswordResetDialog,
                                      child: const Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (kDebugMode) ...[
                                      const SizedBox(height: 8),
                                      OutlinedButton(
                                        onPressed: _testFirebaseEmail,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white70,
                                          side: BorderSide(
                                            color: Colors.white.withValues(
                                              alpha: 0.45,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                        ),
                                        child: const Text(
                                          'Test Firebase Email',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Divider(
                                            color: Colors.white.withValues(
                                              alpha: 0.35,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Text(
                                            'or',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.85,
                                              ),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Divider(
                                            color: Colors.white.withValues(
                                              alpha: 0.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed:
                                          _googleLoading ? null : _signInWithGoogle,
                                      icon: _googleLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.0,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const FaIcon(
                                              FontAwesomeIcons.google,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                      label: Text(
                                        _googleLoading
                                            ? 'Signing in...'
                                            : 'Continue with Google',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: 0.45,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        const Text(
                                          "Don't have an account? ",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF222222),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const CreateAccountScreen(),
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            'Create New Account',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(flex: 2),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPass = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPass,
      style: const TextStyle(color: Colors.black),
      keyboardType: isPass ? TextInputType.visiblePassword : TextInputType.emailAddress,
      textInputAction: isPass ? TextInputAction.done : TextInputAction.next,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.6),
        prefixIcon: Icon(icon, color: Colors.black87),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (value) {
        final input = value?.trim() ?? '';
        if (input.isEmpty) {
          return '$hint is required';
        }
        if (!isPass) {
          final isEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(input);
          if (!isEmail) return 'Enter a valid email address';
        } else if (input.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }
}
