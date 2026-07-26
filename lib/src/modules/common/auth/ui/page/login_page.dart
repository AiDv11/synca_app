import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/core/utils/validators.dart';
import 'package:synca_app/src/modules/common/auth/model/services/auth_service.dart';
import 'package:synca_app/src/modules/common/auth/ui/page/register_page.dart';

/// Sign-in screen.
///
/// A `StatefulWidget` because this screen changes over time: text gets typed,
/// a spinner appears while we wait on Firebase. A `StatelessWidget` can't
/// remember anything between rebuilds, so it can't do either.
///
/// The pattern is always two classes — the widget itself (immutable, cheap to
/// recreate) and a `State` object that survives rebuilds and holds the data.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /// Handle to the `Form` below. Calling `_formKey.currentState!.validate()`
  /// runs every field's validator at once and returns true only if all pass.
  final _formKey = GlobalKey<FormState>();

  /// Controllers give us the text a user typed (`controller.text`) and notify
  /// the field when we change it programmatically.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authService = AuthService();

  /// Drives the spinner. When true the button shows a spinner and stops
  /// accepting taps, which is what prevents a double submission.
  bool _isLoading = false;

  /// Whether the password renders as dots. Toggled by the eye icon.
  bool _obscurePassword = true;

  /// Controllers hold resources that aren't freed automatically. Forgetting
  /// `dispose` leaks memory every time the screen is opened — one of the most
  /// common Flutter mistakes.
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Run the validators first. If anything fails, the messages appear under
    // the fields and we never touch the network.
    if (!_formKey.currentState!.validate()) return;

    // `setState` tells Flutter "my data changed, rebuild this widget". Setting
    // _isLoading without it would change the variable but not the screen.
    setState(() => _isLoading = true);

    try {
      final user = await _authService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // IMPORTANT: `await` means time passed, and the user may have left this
      // screen meanwhile. Touching `context` after the widget is gone throws.
      // `mounted` asks "is this widget still on screen?" — check it after
      // every await before using context.
      if (!mounted) return;

      if (user == null) {
        // Credentials were valid but no Firestore profile exists.
        _showSnackBar('Your profile is missing. Please register again.');
        return;
      }

      _showSnackBar('Welcome back, ${user.name}', isError: false);

      // TODO: route to the member / leader / coordinator home screen based on
      // user.role once those screens exist.
    } on FirebaseAuthException catch (e) {
      // `on ... catch` catches only this type. Firebase reports failures as an
      // exception carrying a `code` we can translate into plain English.
      if (!mounted) return;
      _showSnackBar(_messageForAuthError(e.code));
    } catch (_) {
      // Anything else — no internet, Firestore unreachable. Never show a raw
      // exception to a user; it's noise to them and leaks internals.
      if (!mounted) return;
      _showSnackBar('Something went wrong. Please try again.');
    } finally {
      // `finally` runs on success and on failure, so the spinner always stops.
      // Put this only in the success path and one error would freeze the
      // button forever.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Turns a Firebase error code into something a student can act on.
  String _messageForAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      // Recent Firebase versions return the vaguer 'invalid-credential' for
      // both a wrong password and an unknown account — deliberately, so an
      // attacker can't discover which emails are registered.
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Try again in a few minutes.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Login failed. Please try again.';
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

  void _goToRegister() {
    // `pushReplacement` swaps this screen for the register page instead of
    // stacking it on top. Otherwise bouncing between login and register would
    // pile up screens and the back button would walk through all of them.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      // SafeArea keeps content clear of the notch and status bar.
      body: SafeArea(
        // Without a scroll view the keyboard shrinks the screen and Flutter
        // reports a pixel overflow. This makes the form scrollable instead.
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              // Stretch makes children fill the width, so the button spans the
              // screen rather than shrinking to fit its label.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Synca',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to your group',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.charcoal),
                ),
                const SizedBox(height: 40),

                TextFormField(
                  controller: _emailController,
                  // Shows the @ key on the on-screen keyboard.
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
                  // Makes the phone keyboard's "done" key submit the form.
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
                  // On login we only check it isn't empty. Length rules belong
                  // on registration — an old account might predate them, and
                  // blocking a valid password locally would be a real bug.
                  validator: (value) => Validators.required(value, 'Password'),
                ),
                const SizedBox(height: 32),

                FilledButton(
                  // A null callback is how Flutter disables a button: it greys
                  // out and ignores taps. That's the double-submit guard.
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
                      // Sized explicitly, otherwise the spinner expands to the
                      // button's full height and the button jumps.
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Login',
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
                      "Don't have an account? ",
                      style: TextStyle(color: AppColors.charcoal),
                    ),
                    GestureDetector(
                      onTap: _isLoading ? null : _goToRegister,
                      child: const Text(
                        'Register',
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

  /// Both fields share this styling, so it is built once here rather than
  /// copied. Same idea as a CSS class.
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
      // The border shown when the field has keyboard focus.
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.teal, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.charcoal),
    );
  }
}
