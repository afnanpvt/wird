import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/friends_service.dart';

/// Renders a predefined avatar (see models/avatar_seeds.dart) from its
/// DiceBear "Shapes" SVG - abstract geometric shapes, no human figures.
class FriendAvatar extends StatelessWidget {
  final String seed;
  final double size;

  const FriendAvatar({super.key, required this.seed, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: SvgPicture.string(
        FriendsService.avatarSvgFor(seed),
        width: size,
        height: size,
        placeholderBuilder: (_) => SizedBox(width: size, height: size),
      ),
    );
  }
}
