import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';

/// The Synca mark, as shown above the wordmark on the public screens.
///
/// One widget rather than the same `Image.asset` written out three times. The
/// landing, login and register pages are seen one after another — landing into
/// login, login into register — so a size or corner radius that differed
/// between them would read as the logo jumping about while you move through the
/// app. Sharing it makes that impossible rather than merely unlikely.
///
/// Lives in `modules/common/` because both `onboarding` and `auth` use it, and
/// `common` is where this project already puts things more than one module
/// needs. It is the first widget here, so `common/widgets/` is new — worth
/// knowing, since CLAUDE.md's structure section does not list it yet.
class SyncaLogo extends StatelessWidget {
  const SyncaLogo({super.key, this.size = 80});

  /// Width and height in logical pixels. The mark is square.
  final double size;

  /// The corner radius, as a fraction of [size].
  ///
  /// `assets/branding/icon.png` is drawn as a plain square with hard corners —
  /// on a phone home screen it is the operating system that rounds it. Nothing
  /// rounds it here, so without this it would sit on the page as a hard navy
  /// block and read like a placeholder rather than the app's icon.
  ///
  /// 22.5% is the proportion iOS uses for app icons, which is why a rounded
  /// square at this ratio is recognisable as "an app icon" at a glance.
  /// Expressed as a fraction so the shape holds if [size] changes.
  static const double _cornerRatio = 0.225;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * _cornerRatio),
      child: Image.asset(
        'assets/branding/icon.png',
        width: size,
        height: size,
        // The source is 1052px square and drawn to the edges, so it needs no
        // fitting — but stating it means an accidental change to the artwork's
        // aspect ratio distorts nothing.
        fit: BoxFit.cover,
        // Asset loading can fail — most plausibly on web, where assets come
        // over the network. Rather than Flutter's grey broken-image box on the
        // very first screen anyone sees, fall back to the mark's own navy in
        // the same shape: the layout does not move, and it still looks
        // deliberate. The wordmark below carries the name either way.
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          color: AppColors.navy,
        ),
      ),
    );
  }
}
