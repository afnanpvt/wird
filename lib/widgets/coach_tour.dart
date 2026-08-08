import 'package:flutter/material.dart';

class CoachStep {
  final GlobalKey targetKey;
  final String title;
  final String description;

  const CoachStep({required this.targetKey, required this.title, required this.description});
}

/// Minimal spotlight-style first-run tour: dims the screen, cuts a highlight
/// hole around each target widget in turn, with a caption and Next/Skip.
class CoachTour {
  static void show(BuildContext context, List<CoachStep> steps, {VoidCallback? onDone}) {
    if (steps.isEmpty) {
      onDone?.call();
      return;
    }
    late OverlayEntry entry;
    var index = 0;
    late void Function() showStep;

    void closeAndAdvance() {
      entry.remove();
      index++;
      if (index < steps.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => showStep());
      } else {
        onDone?.call();
      }
    }

    showStep = () {
      entry = OverlayEntry(
        builder: (context) => _CoachOverlay(
          step: steps[index],
          stepNumber: index + 1,
          totalSteps: steps.length,
          onNext: closeAndAdvance,
          onSkip: () {
            entry.remove();
            onDone?.call();
          },
        ),
      );
      Overlay.of(context, rootOverlay: true).insert(entry);
    };

    showStep();
  }
}

class _CoachOverlay extends StatelessWidget {
  final CoachStep step;
  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _CoachOverlay({
    required this.step,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  Rect? _targetRect() {
    final box = step.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(topLeft.dx, topLeft.dy, box.size.width, box.size.height);
  }

  @override
  Widget build(BuildContext context) {
    final rect = _targetRect();
    final screenSize = MediaQuery.of(context).size;
    final colorScheme = Theme.of(context).colorScheme;
    final highlight = rect?.inflate(8) ?? Rect.fromLTWH(screenSize.width / 2, screenSize.height / 2, 0, 0);

    final captionBelow = highlight.top < screenSize.height * 0.55;
    final captionTop = captionBelow ? highlight.bottom + 16 : null;
    final captionBottom = captionBelow ? null : screenSize.height - highlight.top + 16;

    // Wrapped in a Material because this is inserted into the root Overlay,
    // outside the app's Scaffold/Material ancestry - without it, the Text
    // widgets below don't inherit the themed DefaultTextStyle (Inter) and
    // fall back to the platform default font.
    return Material(
      color: Colors.transparent,
      child: Stack(
      children: [
        // Scrim is decorative only - no tap handler. A GestureDetector here
        // would sit in the same hit-test pass as the Next/Skip/Done buttons
        // below and can double-fire onNext for a single tap, silently
        // skipping a step. Only the explicit buttons advance the tour.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SpotlightPainter(highlight),
              size: Size.infinite,
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          top: captionTop,
          bottom: captionBottom,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) => Opacity(opacity: value, child: child),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(step.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(step.description, style: TextStyle(fontSize: 13.5, height: 1.4, color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('$stepNumber/$totalSteps', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                      const Spacer(),
                      TextButton(onPressed: onSkip, child: const Text('Skip')),
                      const SizedBox(width: 4),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.onSurface,
                          foregroundColor: colorScheme.surface,
                        ),
                        onPressed: onNext,
                        child: Text(stepNumber == totalSteps ? 'Done' : 'Next'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect highlight;

  _SpotlightPainter(this.highlight);

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.65);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(highlight, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, scrim);
    canvas.drawRRect(
      RRect.fromRectAndRadius(highlight, const Radius.circular(16)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) => oldDelegate.highlight != highlight;
}
