import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_profile.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> registerUser() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      _showError('Please fix the highlighted fields.');
      return;
    }

    if (passwordController.text.trim() != confirmController.text.trim()) {
      _showError("Passwords do not match");
      return;
    }

    if (passwordController.text.trim().length < 6) {
      _showError("Password must be at least 6 characters");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = cred.user;
      if (user == null) {
        throw Exception('Failed to create account. Please try again.');
      }

      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': nameController.text.trim(),
          'full_name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'skills': <dynamic>[],
          'targetJobId': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (firestoreError) {
        // Keep auth and profile in sync: if profile doc creation fails, rollback account.
        await user.delete();
        throw Exception(
          'Account created but profile setup failed. Please try again. '
          '(${firestoreError.toString()})',
        );
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CreateProfileScreen()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String errorMsg = "An error occurred";
      if (e.code == 'weak-password') errorMsg = "The password is too weak.";
      if (e.code == 'email-already-in-use') {
        errorMsg = "This email is already in use.";
      }
      if (e.code == 'invalid-email') {
        errorMsg = "The email address is badly formatted.";
      }

      _showError(errorMsg);
    } catch (_) {
      if (!mounted) return;
      _showError("Unexpected issue. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
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
            colors: [Color(0xFF2A6CFF), Color(0xFF9226FF)],
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

                        /// Registration Card
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Create Account',
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
                                            nameController,
                                            'Full Name',
                                            Icons.person_outline,
                                          ),
                                          const SizedBox(height: 18),
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
                                          const SizedBox(height: 18),
                                          _buildTextField(
                                            confirmController,
                                            'Confirm Password',
                                            Icons.lock_outline,
                                            isPass: true,
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 25),

                                    ElevatedButton(
                                      onPressed: _isLoading ? null : registerUser,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(
                                          0xFF2A6CFF,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 15,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        elevation: 5,
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                              ),
                                            )
                                          : const Text(
                                              'Create Account',
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),

                                    const SizedBox(height: 20),

                                    GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: const Text(
                                        "Already have an account? Login",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
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
      style: const TextStyle(color: Colors.white),
      keyboardType: (!isPass && hint == 'Email')
          ? TextInputType.emailAddress
          : TextInputType.text,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        prefixIcon: Icon(icon, color: Colors.white70),
      ),
      validator: (value) {
        final input = value?.trim() ?? '';
        if (input.isEmpty) return '$hint is required';
        if (hint == 'Email') {
          final isEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(input);
          if (!isEmail) return 'Enter a valid email address';
        }
        if (hint == 'Password' && input.length < 6) {
          return 'Password must be at least 6 characters';
        }
        if (hint == 'Confirm Password' && input != passwordController.text.trim()) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }
}
