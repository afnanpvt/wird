import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The bookmark-ribbon motif used everywhere Google backup is offered or
/// managed - deliberately not a generic cloud/lock icon. It's the same
/// shape as the app's actual bookmark feature, since "your place, kept" is
/// literally what backup does: it's the bookmark that survives a reinstall.
class BackupRibbonIcon extends StatelessWidget {
  final double size;
  final Color color;

  const BackupRibbonIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/backup_ribbon.svg',
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
