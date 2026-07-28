import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';

/// One choice in the avatar picker: an icon on a coloured circle.
///
/// No photographs and no uploads. Firebase Storage isn't on the project's plan,
/// and a fixed set of icons sidesteps the whole problem — nothing to store, no
/// image to moderate, and every avatar renders instantly with no network call.
class PresetAvatar {
  const PresetAvatar({
    required this.id,
    required this.icon,
    required this.background,
  });

  /// The value written to Firestore, e.g. `avatar_03`.
  ///
  /// Stable and opaque on purpose. Storing the icon's *name* would tie the
  /// database to Flutter's icon set, so renaming or swapping an icon later
  /// would orphan every user who picked it. An id means the meaning of
  /// `avatar_03` is decided here, in code, and can be changed freely.
  final String id;

  final IconData icon;

  /// Always a brand colour. The icon itself is drawn white, so every option
  /// needs a background dark enough to carry it — which is why
  /// [AppColors.light] never appears below.
  final Color background;
}

/// The fixed set of avatars, and the lookup that turns a stored id back into
/// one.
abstract final class PresetAvatars {
  /// Twelve options: four brand colours across three icons each.
  ///
  /// Twelve is enough that a group of five or six can each look distinct,
  /// while still fitting a short grid without scrolling. The ids are padded
  /// (`avatar_01`, not `avatar_1`) so they sort correctly as strings if they
  /// ever end up in a sorted list or a console listing.
  ///
  /// The order here is the order shown in the picker. Adding to the end is
  /// safe; **renumbering is not** — an id already written to a user document
  /// would start meaning a different picture.
  static const List<PresetAvatar> all = [
    PresetAvatar(
      id: 'avatar_01',
      icon: Icons.school,
      background: AppColors.navy,
    ),
    PresetAvatar(
      id: 'avatar_02',
      icon: Icons.menu_book,
      background: AppColors.teal,
    ),
    PresetAvatar(
      id: 'avatar_03',
      icon: Icons.code,
      background: AppColors.skyBlue,
    ),
    PresetAvatar(
      id: 'avatar_04',
      icon: Icons.brush,
      background: AppColors.charcoal,
    ),
    PresetAvatar(
      id: 'avatar_05',
      icon: Icons.science,
      background: AppColors.teal,
    ),
    PresetAvatar(
      id: 'avatar_06',
      icon: Icons.calculate,
      background: AppColors.navy,
    ),
    PresetAvatar(
      id: 'avatar_07',
      icon: Icons.lightbulb,
      background: AppColors.charcoal,
    ),
    PresetAvatar(
      id: 'avatar_08',
      icon: Icons.rocket_launch,
      background: AppColors.skyBlue,
    ),
    PresetAvatar(
      id: 'avatar_09',
      icon: Icons.sports_esports,
      background: AppColors.navy,
    ),
    PresetAvatar(
      id: 'avatar_10',
      icon: Icons.music_note,
      background: AppColors.teal,
    ),
    PresetAvatar(
      id: 'avatar_11',
      icon: Icons.camera_alt,
      background: AppColors.skyBlue,
    ),
    PresetAvatar(
      id: 'avatar_12',
      icon: Icons.pets,
      background: AppColors.charcoal,
    ),
  ];

  /// Finds an avatar by id, or null if there isn't one.
  ///
  /// Null is a normal answer, not an error, and it happens in three ordinary
  /// cases: the user has never picked an avatar, their document predates this
  /// feature, or the id was removed from [all] in a later version. All three
  /// mean the same thing to the UI — fall back to the initial-letter circle.
  ///
  /// A plain loop rather than `firstWhere`, because `firstWhere` throws when
  /// nothing matches and its `orElse` would need a fake avatar to return.
  static PresetAvatar? byId(String? id) {
    if (id == null) return null;

    for (final avatar in all) {
      if (avatar.id == id) return avatar;
    }
    return null;
  }
}
