import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/common/auth/model/services/auth_service.dart';
import 'package:synca_app/src/modules/common/onboarding/ui/page/landing_page.dart';
import 'package:synca_app/src/modules/role/coordinator/ui/page/coordinator_dashboard.dart';
import 'package:synca_app/src/modules/role/leader/ui/page/leader_dashboard.dart';
import 'package:synca_app/src/modules/role/member/ui/page/member_dashboard.dart';

/// Decides which screen the app opens on, and keeps that decision up to date.
///
/// This is the app's `home`, so it is the first thing built. It answers two
/// questions in order:
///
///   1. Is anyone signed in?  → no: [LandingPage]
///   2. What is their role?   → member / leader / coordinator dashboard
///
/// Because step 1 listens to a *stream*, the gate reacts on its own. Log out
/// from any dashboard and Firebase pushes a new value, the gate rebuilds, and
/// the landing page appears — no `Navigator` call anywhere. Same on login. That
/// is the whole appeal of this pattern: sign-in state lives in one place.
///
/// One wrinkle comes from the landing page. Login and Register are *pushed* on
/// top of this gate as routes, so when signing in succeeds the gate does
/// rebuild into a dashboard — but underneath the login screen still covering
/// it. That is why those two pages pop themselves once they succeed; see the
/// note in `LoginPage._submit`.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();

  /// The stream is stored in a field and created once in [initState], never
  /// inside `build`. `build` can run many times a second; creating a stream
  /// there would make `StreamBuilder` unsubscribe and resubscribe on every
  /// rebuild, flashing the loading spinner each time. Rule of thumb: streams
  /// and futures are created in `initState`, not `build`.
  late final Stream<User?> _authState;

  @override
  void initState() {
    super.initState();
    _authState = _authService.authStateChanges();
  }

  @override
  Widget build(BuildContext context) {
    // StreamBuilder rebuilds this subtree every time the stream emits.
    return StreamBuilder<User?>(
      stream: _authState,
      builder: (context, snapshot) {
        // On startup Firebase reads the saved session from disk. Until that
        // finishes we know nothing — showing LoginPage here would make it
        // flash on screen for already-signed-in users.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final firebaseUser = snapshot.data;
        if (firebaseUser == null) {
          return const LandingPage();
        }

        // Signed in, but Firebase Auth doesn't know the role — that lives in
        // Firestore. _RoleRouter fetches it.
        //
        // The `key` matters. Without it, signing out and back in as someone
        // else would reuse the existing _RoleRouter state, which fetched the
        // *previous* user's profile and never refetches. Changing the key
        // tells Flutter "this is a different widget", so it rebuilds from
        // scratch and fetches again.
        return _RoleRouter(key: ValueKey(firebaseUser.uid));
      },
    );
  }
}

/// Loads the signed-in user's Synca profile, then shows the right dashboard.
///
/// Stateful because the fetch must happen exactly once, when this widget is
/// first created — not on every rebuild.
class _RoleRouter extends StatefulWidget {
  const _RoleRouter({super.key});

  @override
  State<_RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<_RoleRouter> {
  final _authService = AuthService();

  /// The in-flight fetch. Held in a field for the same reason as the stream
  /// above: calling `getCurrentUser()` directly in `build` would start a fresh
  /// Firestore read on every rebuild — a subtle, expensive bug.
  late Future<AppUser?> _profileFuture;

  /// `initState` runs once when the widget is inserted into the tree. It is
  /// the standard place to kick off loading.
  @override
  void initState() {
    super.initState();
    _profileFuture = _authService.getCurrentUser();
  }

  /// Replacing the future inside `setState` is what makes a retry work — the
  /// FutureBuilder sees a new future and starts over.
  void _retry() {
    setState(() {
      _profileFuture = _authService.getCurrentUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    // FutureBuilder is StreamBuilder's one-shot cousin: it rebuilds when the
    // future completes.
    return FutureBuilder<AppUser?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        // The read itself failed — offline, or Firestore rules said no.
        // Recoverable, so offer a retry rather than dumping them at login.
        if (snapshot.hasError) {
          return _MessageScreen(
            icon: Icons.cloud_off,
            message: "We couldn't load your profile.\nCheck your connection.",
            actionLabel: 'Retry',
            onAction: _retry,
          );
        }

        final user = snapshot.data;

        // Read succeeded but there is no document: the account exists in
        // Firebase Auth with no matching profile. This is the orphaned-account
        // case from registration — signing out is the only way forward, since
        // without a role the app has no screen to show them.
        if (user == null) {
          return _MessageScreen(
            icon: Icons.person_off_outlined,
            message:
                'Your account has no Synca profile.\n'
                'Please sign out and register again.',
            actionLabel: 'Sign out',
            onAction: _authService.logout,
          );
        }

        // Dart checks that a switch on an enum covers every value, so adding a
        // fourth role later turns into a compile error here rather than a
        // blank screen at runtime.
        switch (user.role) {
          case UserRole.member:
            // The member screens need the uid, name and group id, so the
            // profile we just loaded is handed straight down instead of every
            // screen fetching it again.
            return MemberDashboard(user: user);
          case UserRole.leader:
            return const LeaderDashboard();
          case UserRole.coordinator:
            return const CoordinatorDashboard();
        }
      },
    );
  }
}

/// Full-screen spinner, shown while Firebase or Firestore is being read.
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.light,
      body: Center(child: CircularProgressIndicator(color: AppColors.teal)),
    );
  }
}

/// Full-screen message with one action, for the two dead ends above.
class _MessageScreen extends StatelessWidget {
  const _MessageScreen({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: AppColors.navy),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: AppColors.charcoal),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
