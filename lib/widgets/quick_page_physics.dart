import 'package:flutter/widgets.dart';

/// A page-snapping [ScrollPhysics] that commits to the next/previous page
/// once a swipe has covered [commitFraction] of the viewport, instead of
/// the roughly 50% drag that stock [PageScrollPhysics] requires for a slow,
/// deliberate release. (A fast flick already turns the page at almost any
/// distance via the velocity check below - this only changes the threshold
/// for an unhurried drag-and-lift, which is what made swiping feel like it
/// needed a long drag.)
///
/// [PageView] always wraps whatever `physics` it's given in its own stock
/// [PageScrollPhysics] when `pageSnapping` is true, which would silently
/// override this class's threshold - so callers must also pass
/// `pageSnapping: false` for this to actually take effect.
class QuickPageScrollPhysics extends ScrollPhysics {
  const QuickPageScrollPhysics({super.parent = const BouncingScrollPhysics(), this.commitFraction = 0.2});

  final double commitFraction;

  static const _epsilon = 1e-10;

  @override
  QuickPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return QuickPageScrollPhysics(parent: buildParent(ancestor), commitFraction: commitFraction);
  }

  // Stiffer than stock PageScrollPhysics (100.0) so the page settles into
  // place promptly instead of drifting the last few pixels, which is most of
  // what reads as a "floaty" or unresponsive swipe. Kept over-damped
  // (ratio > 1) so it still never overshoots and bounces.
  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(mass: 0.5, stiffness: 180.0, ratio: 1.1);

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final page = position.pixels / position.viewportDimension;
    final basePage = page.floorToDouble();
    final fraction = page - basePage;

    double targetPage;
    if (velocity < -tolerance.velocity) {
      targetPage = basePage;
    } else if (velocity > tolerance.velocity) {
      targetPage = basePage + 1;
    } else if (fraction > commitFraction) {
      targetPage = basePage + 1;
    } else {
      targetPage = basePage;
    }

    final target = targetPage * position.viewportDimension;
    if ((target - position.pixels).abs() < _epsilon) return null;
    return ScrollSpringSimulation(spring, position.pixels, target, velocity, tolerance: tolerance);
  }
}
