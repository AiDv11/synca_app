import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/core/utils/validators.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/common/auth/model/services/auth_service.dart';
import 'package:synca_app/src/modules/common/auth/ui/page/login_page.dart';

/// Sign-up screen: name, email, password, role.
///
/// The role dropdown below reads `role.label`, which now comes from the
/// `UserRole` enum itself. This file used to declare an `extension` supplying
/// that getter, but a real member on the enum always wins over an extension —
/// so once `UserRole.label` existed the extension here was dead code that
/// merely looked like it was doing the work. It has been removed.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authService = AuthService();

  /// The dropdown's current choice. It starts as `member` rather than null so
  /// the field is never empty — the safest default if someone taps past it.
  UserRole _selectedRole = UserRole.member;

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await _authService.register(
        email: _emailController.text,
        password: _passwordController.text,
        name: _nameController.text,
        role: _selectedRole,
      );

      // The widget may have been removed while we waited — always re-check
      // before using `context` after an await.
      if (!mounted) return;

      _showSnackBar('Account created for ${user.name}', isError: false);

      // Registering signs the new user in, so the auth stream has already
      // fired and AuthGate underneath has rebuilt into their dashboard.
      // Closing this route reveals it. Same reasoning as `LoginPage._submit`:
      // the gate decides which screen a role gets, not this page.
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnackBar(_messageForAuthError(e.code));
    } catch (_) {
      // Covers the awkward case where the Auth account was created but the
      // Firestore profile write failed — the account exists with no profile.
      if (!mounted) return;
      _showSnackBar('Could not finish creating your account. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _messageForAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'That email is already registered. Try logging in.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email sign-up is disabled for this project.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Registration failed. Please try again.';
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : AppColors.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _goToLogin() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Create account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join your group on Synca',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.charcoal),
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _nameController,
                  // Capitalises each word, which suits a person's name.
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading,
                  decoration: _inputDecoration(
                    label: 'Full name',
                    icon: Icons.person_outline,
                  ),
                  validator: (value) => Validators.required(value, 'Name'),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading,
                  decoration: _inputDecoration(
                    label: 'Email',
                    icon: Icons.email_outlined,
                  ),
                  validator: Validators.email,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  enabled: !_isLoading,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _isLoading ? null : _submit(),
                  decoration: _inputDecoration(
                    label: 'Password',
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.charcoal,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),
                  // The full rule here (not empty, at least 6 characters),
                  // because this is where the password is chosen.
                  validator: Validators.password,
                ),
                const SizedBox(height: 16),

                // The generic `<UserRole>` tells Dart what each item carries,
                // so `onChanged` hands back a real UserRole, not a String.
                DropdownButtonFormField<UserRole>(
                  initialValue: _selectedRole,
                  decoration: _inputDecoration(
                    label: 'Role',
                    icon: Icons.badge_outlined,
                  ),
                  items: UserRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(
                        role.label,
                        style: const TextStyle(color: AppColors.charcoal),
                      ),
                    );
                  }).toList(),
                  // Null while loading disables the dropdown, matching the
                  // disabled button and text fields.
                  onChanged: _isLoading
                      ? null
                      : (role) {
                          if (role != null) {
                            setState(() => _selectedRole = role);
                          }
                        },
                ),
                const SizedBox(height: 32),

                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Register',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(color: AppColors.charcoal),
                    ),
                    GestureDetector(
                      onTap: _isLoading ? null : _goToLogin,
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: AppColors.skyBlue,
                          fontWeight: FontWeight.w600,
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
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.navy),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.teal, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.charcoal),
    );
  }
}
