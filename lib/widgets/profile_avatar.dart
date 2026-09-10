import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/avatar_seeds.dart';

/// Renders a predefined avatar (see models/avatar_seeds.dart) - core app
/// identity, used on the home screen's profile button, the Profile screen,
/// onboarding's avatar step, and (once Friends is enabled) the Friends
/// leaderboard.
class ProfileAvatar extends StatelessWidget {
  final String seed;
  final double size;

  const ProfileAvatar({super.key, required this.seed, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: SvgPicture.string(
        avatarSvgFor(seed),
        width: size,
        height: size,
        placeholderBuilder: (_) => SizedBox(width: size, height: size),
      ),
    );
  }
}
