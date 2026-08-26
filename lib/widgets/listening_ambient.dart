import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../main.dart' show WirdColors;

/// The Now Playing screen living background: a few large, very soft radial
/// glows drifting on slow overlapping orbits behind the ayah text.
///
/// Design constraints this is built around:
/// - Typography stays the hero. Every glow sits far below the ink in visual
///   weight (light-mode glows are pale washes on cream, dark-mode embers are
///   dim warm lights on near-black), and a scrim fades the canvas back into
///   the plain background color at the top and bottom edges, so the app bar,
///   status bar, and screen transitions stay calm and text contrast never
///   dips.
/// - The drift must never read as a visible loop. All blobs share one 60s
///   master clock but orbit at non-integer frequency ratios, so the combined
///   pattern takes far longer than any listening session to repeat.
/// - Motion answers playback: glows run brighter and fuller while recitation
///   plays, then settle down dimmed and slower-feeling when paused.
/// - Honors the system reduce-motion setting by freezing the drift at a
///   pleasant static arrangement instead of animating.

/// Extra glow hues that live outside the core palette - warm neighbors of the
/// clay accent, chosen per theme so they read as ambience rather than color
/// blocks against the ayah text.
const _apricot = Color(0xFFF0B483);
const _sandGlow = Color(0xFFEAD9BE);
const _deepEmber = Color(0xFF7E3414);
const _softGold = Color(0xFFE2A85F);

class _BlobSpec {
  const _BlobSpec({
    required this.anchor,
    required this.radiusFactor,
    required this.orbitDx,
    required this.orbitDy,
    required this.frequency,
    required this.lightColor,
    required this.lightOpacity,
    required this.darkColor,
    required this.darkOpacity,
  });

  /// Rest position of the blob center, as fractions of width/height.
  final Offset anchor;

  /// Blob radius as a fraction of the smaller screen dimension.
  final double radiusFactor;

  /// Orbit extents as fractions of width/height - how far the center roams.
  final double orbitDx;
  final double orbitDy;

  /// Orbits per master-clock cycle. Non-integer values relative to each other
  /// are what keep the combined pattern from visibly repeating.
  final double frequency;

  final Color lightColor;
  final double lightOpacity;
  final Color darkColor;
  final double darkOpacity;
}

const _blobs = <_BlobSpec>[
  _BlobSpec(
    anchor: Offset(0.22, 0.16),
    radiusFactor: 0.62,
    orbitDx: 0.15,
    orbitDy: 0.09,
    frequency: 1.0,
    lightColor: WirdColors.clayLight,
    lightOpacity: 0.10,
    darkColor: WirdColors.clayDark,
    darkOpacity: 0.13,
  ),
  _BlobSpec(
    anchor: Offset(0.85, 0.52),
    radiusFactor: 0.54,
    orbitDx: 0.12,
    orbitDy: 0.14,
    frequency: 0.73,
    lightColor: _apricot,
    lightOpacity: 0.24,
    darkColor: _softGold,
    darkOpacity: 0.10,
  ),
  _BlobSpec(
    anchor: Offset(0.50, 0.95),
    radiusFactor: 0.60,
    orbitDx: 0.10,
    orbitDy: 0.07,
    frequency: 0.62,
    lightColor: _sandGlow,
    lightOpacity: 0.36,
    darkColor: _deepEmber,
    darkOpacity: 0.15,
  ),
];

class ListeningAmbient extends StatefulWidget {
  const ListeningAmbient({super.key, required this.playing});

  /// Whether recitation is currently playing. Drives glow intensity - full
  /// and lively while playing, dimmed while paused.
  final bool playing;

  @override
  State<ListeningAmbient> createState() => _ListeningAmbientState();
}

class _ListeningAmbientState extends State<ListeningAmbient>
    with SingleTickerProviderStateMixin {
  /// Master clock for every blob orbit. One shared ticker keeps all motion on
  /// a single repaint schedule; blobs differentiate by frequency multiplier.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();

  /// How alive the glows look right now - 1.0 while playing, 0.55 paused.
  /// Animated so pausing feels like the room settling, not a light switch.
  late final AnimationController _intensity = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: widget.playing ? 1.0 : 0.55,
  );

  @override
  void didUpdateWidget(covariant ListeningAmbient oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) {
      _intensity.animateTo(
        widget.playing ? 1.0 : 0.55,
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    _intensity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: Listenable.merge([_drift, _intensity]),
      builder: (context, _) {
        // Re-animates whenever [dark] flips, lerping every palette entry
        // between its light and dark variants instead of snapping when the
        // theme changes mid-session.
        return TweenAnimationBuilder<double>(
          tween: Tween(end: dark ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (context, darkMix, _) => CustomPaint(
            size: Size.infinite,
            painter: _AmbientPainter(
              phase: reduceMotion ? 0.12 : _drift.value,
              intensity: reduceMotion ? 0.7 : _intensity.value,
              darkMix: darkMix,
            ),
          ),
        );
      },
    );
  }
}

class _AmbientPainter extends CustomPainter {
  const _AmbientPainter({
    required this.phase,
    required this.intensity,
    required this.darkMix,
  });

  /// Master-clock position, 0..1. Frozen at a fixed value under reduce-motion.
  final double phase;

  /// Playback-driven brightness multiplier, roughly 0.55..1.0.
  final double intensity;

  /// 0.0 = full light palette, 1.0 = full dark palette.
  final double darkMix;

  Color _mix(Color light, Color dark) => Color.lerp(light, dark, darkMix)!;

  double _mixDouble(double light, double dark) =>
      light + (dark - light) * darkMix;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final minDim = math.min(w, h);
    final tau = math.pi * 2;

    for (final blob in _blobs) {
      final angle = tau * phase * blob.frequency;
      final center = Offset(
        (blob.anchor.dx + math.sin(angle) * blob.orbitDx) * w,
        (blob.anchor.dy + math.cos(angle) * blob.orbitDy) * h,
      );
      final radius = blob.radiusFactor * minDim;
      final opacity =
          (_mixDouble(blob.lightOpacity, blob.darkOpacity) * intensity)
              .clamp(0.0, 1.0);
      final color = _mix(blob.lightColor, blob.darkColor);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    // Vertical scrim: fade the canvas into the plain background color at the
    // very top and bottom, so the app bar area and the screen edge the user
    // swipes away from stay quiet, and nothing competes with the ayah text.
    final background = _mix(WirdColors.backgroundLight, WirdColors.backgroundDark);
    final scrim = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.22, 0.78, 1.0],
        colors: [
          background.withValues(alpha: 0.9),
          background.withValues(alpha: 0.0),
          background.withValues(alpha: 0.0),
          background.withValues(alpha: 0.9),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, scrim);
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.intensity != intensity ||
      oldDelegate.darkMix != darkMix;
}
