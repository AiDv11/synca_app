import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/role/member/model/preset_avatar.dart';

/// A member's avatar circle: their chosen preset, or the first letter of their
/// name if they haven't chosen one.
///
/// The fallback is the important half. Every account created before this
/// feature existed has no `avatarId`, so "no choice yet" is the common case,
/// not an edge case — and a blank circle would look broken. The initial letter
/// is what the Profile tab already showed, so nothing regresses.
///
/// One widget rather than the same `CircleAvatar` written out in the profile
/// and again in the picker: the two must agree, or the option a member taps in
/// the grid won't be the picture they end up with.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.avatarId,
    required this.name,
    this.radius = 20,
  });

  /// The stored id, e.g. `avatar_03`. Null, or an id no longer in
  /// [PresetAvatars.all], both fall back to the letter.
  final String? avatarId;

  /// Used only for the fallback letter.
  final String name;

  /// Half the circle's width, in logical pixels — [CircleAvatar]'s own unit.
  /// The icon and letter are sized from this, so one number scales the whole
  /// thing and a small circle in a list can share this widget with the big one
  /// on the profile.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final preset = PresetAvatars.byId(avatarId);

    if (preset != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: preset.background,
        child: Icon(preset.icon, color: Colors.white, size: radius),
      );
    }

    // A name could in theory be empty, and `''[0]` throws a range error rather
    // than returning nothing — a crash on a screen that just shows a letter.
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.navy,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          // 0.8 rather than a fixed size: a capital letter has to sit inside
          // the circle with room to breathe at every radius this is used at.
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
