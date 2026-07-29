import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/common/auth/ui/page/login_page.dart';
import 'package:synca_app/src/modules/common/auth/ui/page/register_page.dart';
import 'package:synca_app/src/modules/common/widgets/synca_logo.dart';

/// The public front door of the app — Figure 1 in the approved proposal.
///
/// Shown by `AuthGate` whenever nobody is signed in. Its job is to say what
/// Synca is and offer the two ways in; it holds no state and touches no
/// service, which is why it is a plain [StatelessWidget].
///
/// The three role cards are not decoration. A student arriving from a module
/// handbook needs to recognise themselves before signing up, because the role
/// they pick on the register screen decides what the app looks like afterwards.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  void _goToLogin(BuildContext context) {
    // `push`, not `pushReplacement`: the landing page stays underneath, so the
    // back button and the Android system gesture return here rather than
    // closing the app.
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  void _goToRegister(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegisterPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      body: SafeArea(
        // Everything is inside a scroll view because this page has to survive a
        // short screen. On a small phone the three cards would otherwise run
        // past the bottom edge and Flutter would paint its yellow-and-black
        // overflow stripes.
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            // Stretch makes the buttons fill the width instead of shrinking to
            // fit their labels.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // The mark sits above the wordmark rather than replacing it —
              // this is the first screen anyone sees, and a logo alone would
              // not tell a new student what the app is called.
              const Center(child: SyncaLogo()),
              const SizedBox(height: 20),

              Text(
                'Synca',
                textAlign: TextAlign.center,
                // Pulling the size from the theme's text scale rather than
                // hardcoding a number keeps headings consistent across screens
                // — the login page builds its title the same way.
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Coordinate group projects, without the chaos',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'Know who owns each task, watch progress as it happens, '
                'and keep every deadline in plain sight.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.charcoal,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),

              // Log In is the filled button and sits first: returning users are
              // the common case, and a filled button is the louder of the two.
              FilledButton(
                onPressed: () => _goToLogin(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Log In',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: () => _goToRegister(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  side: const BorderSide(color: AppColors.teal, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Register',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 36),

              const _RoleCard(
                icon: Icons.checklist_outlined,
                title: 'For Group Members',
                description:
                    'Claim tasks, upload proof, track your '
                    'contribution',
              ),
              const SizedBox(height: 12),
              const _RoleCard(
                icon: Icons.dashboard_outlined,
                title: 'For Group Leaders',
                description:
                    'Live dashboard, at-risk task alerts, '
                    'reassignment',
              ),
              const SizedBox(height: 12),
              const _RoleCard(
                icon: Icons.insights_outlined,
                title: 'For Module Coordinators',
                description: 'High-level submission health across all groups',
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the three "what you get" cards.
///
/// A private widget (`_` prefix) because nothing outside this file needs it.
/// Pulling the repeated card out means the three differ only in their content,
/// so they cannot drift apart visually.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        // Icon lines up with the title rather than floating in the middle of a
        // two-line card.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              // Sky blue at 12% — the same tinted-pill treatment the status
              // chips use, so the app looks like one thing.
              color: AppColors.skyBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.skyBlue),
          ),
          const SizedBox(width: 14),

          // Expanded stops the description from pushing past the card's edge;
          // without it a long line would overflow instead of wrapping.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
