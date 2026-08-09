import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wird/widgets/coach_tour.dart';

void main() {
  testWidgets('scrolls an off-screen target into view before spotlighting it', (tester) async {
    // Mirrors Home's shape: three keyed targets in a scrolling column, the
    // last one (like the Browse button) well below the fold on a short
    // viewport. tester's default surface is 800x600.
    final topKey = GlobalKey();
    final middleKey = GlobalKey();
    final bottomKey = GlobalKey();
    late BuildContext scaffoldContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              scaffoldContext = context;
              return SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(key: topKey, height: 40, child: const Text('top')),
                    const SizedBox(height: 1000),
                    SizedBox(key: middleKey, height: 40, child: const Text('middle')),
                    const SizedBox(height: 1000),
                    SizedBox(key: bottomKey, height: 40, child: const Text('bottom')),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    // Before the tour touches it, the bottom target is far outside the
    // 600pt-tall viewport - this is the state that used to break the
    // spotlight.
    final beforeBox = bottomKey.currentContext!.findRenderObject() as RenderBox;
    expect(beforeBox.localToGlobal(Offset.zero).dy, greaterThan(600));

    var done = false;
    CoachTour.show(
      scaffoldContext,
      [
        CoachStep(targetKey: topKey, title: 'Top', description: 'first'),
        CoachStep(targetKey: middleKey, title: 'Middle', description: 'second'),
        CoachStep(targetKey: bottomKey, title: 'Bottom', description: 'third'),
      ],
      onDone: () => done = true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Now on the third step: the target must have been scrolled into the
    // visible viewport before its rect was measured, or the spotlight would
    // still be circling whatever used to be at its old, off-screen position.
    expect(find.text('Bottom'), findsOneWidget);
    final afterBox = bottomKey.currentContext!.findRenderObject() as RenderBox;
    final afterRect = Rect.fromLTWH(
      afterBox.localToGlobal(Offset.zero).dx,
      afterBox.localToGlobal(Offset.zero).dy,
      afterBox.size.width,
      afterBox.size.height,
    );
    final viewport = Rect.fromLTWH(0, 0, 800, 600);
    expect(
      viewport.overlaps(afterRect),
      isTrue,
      reason: 'target should be inside the viewport after ensureVisible, was $afterRect',
    );

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
  });
}
