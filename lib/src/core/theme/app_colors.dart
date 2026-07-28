import 'package:flutter/material.dart';

/// Synca's brand colours.
///
/// Every colour in the app comes from here, so a rebrand means editing one
/// file instead of hunting through widgets for stray hex codes.
///
/// The class is `abstract final` so nobody can create an `AppColors()` object
/// or extend it — it exists purely as a namespace for the constants below.
/// Use them like `AppColors.navy`.
abstract final class AppColors {
  /// Primary brand colour — app bars, headers, primary buttons. `#0D1B3D`
  ///
  /// The `0xFF` prefix is the alpha (opacity) channel: `FF` = fully opaque.
  /// The remaining six digits are the usual RGB hex you'd write in CSS.
  static const Color navy = Color(0xFF0D1B3D);

  /// Accent colour — call-to-action buttons, active states, progress. `#00B7B3`
  static const Color teal = Color(0xFF00B7B3);

  /// Secondary highlight — links, chips, selected items. `#5BAEF5`
  static const Color skyBlue = Color(0xFF5BAEF5);

  /// Page backgrounds and card surfaces. `#F5F7FA`
  static const Color light = Color(0xFFF5F7FA);

  /// Body text and icons on light backgrounds. `#1F2937`
  static const Color charcoal = Color(0xFF1F2937);

  /// Overdue work, error messages, destructive actions. `#DC2626`
  ///
  /// The one colour here that is not in the approved proposal's palette. It had
  /// to be added: "late" has to read as a warning at a glance, and none of the
  /// five brand colours says that — navy and charcoal are the ordinary text
  /// colours, and teal and sky blue both read as positive.
  ///
  /// Named for its job rather than its hue, because that is the whole point of
  /// it. Red in this app means "something is wrong"; anything using it
  /// decoratively would blunt the one signal it carries.
  static const Color danger = Color(0xFFDC2626);
}
