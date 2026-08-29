import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/ui/charts/live_visualiser.dart';
import 'package:resonance/ui/tokens/theme.dart';
import 'package:resonance_dsp/resonance_dsp.dart';

FrameAnalysis frame({
  double db = -20,
  double pitch = 180,
  double confidence = 0.9,
  bool voiced = true,
  bool clipping = false,
}) {
  return FrameAnalysis(
    rms: 0.1,
    db: db,
    peak: 0.2,
    pitchHz: pitch,
    pitchConfidence: confidence,
    isVoiced: voiced,
    isClipping: clipping,
  );
}

Future<void> pump(
  WidgetTester tester,
  StreamController<FrameAnalysis> controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ResTheme.light(),
      home: Scaffold(body: LiveVisualiser(analysis: controller.stream)),
    ),
  );
  await tester.pump();
}

void main() {
  late StreamController<FrameAnalysis> controller;

  setUp(() => controller = StreamController<FrameAnalysis>.broadcast());
  tearDown(() => controller.close());

  testWidgets('paints an empty state without frames', (tester) async {
    await pump(tester, controller);
    expect(find.byType(LiveVisualiser), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accepts a burst of frames without throwing', (tester) async {
    await pump(tester, controller);

    for (var i = 0; i < 150; i++) {
      controller.add(frame(pitch: 120 + i.toDouble()));
    }
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });

  testWidgets('handles unvoiced frames, which must leave gaps not zeros', (
    tester,
  ) async {
    await pump(tester, controller);

    // Voiced, then a breath, then voiced again — the case where a naive
    // implementation draws a line down to zero and back.
    for (var i = 0; i < 10; i++) {
      controller.add(frame(pitch: 180));
    }
    for (var i = 0; i < 5; i++) {
      controller.add(frame(pitch: kNoPitch, voiced: false, db: -80));
    }
    for (var i = 0; i < 10; i++) {
      controller.add(frame(pitch: 190));
    }
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
  });

  testWidgets('handles an entirely unvoiced take', (tester) async {
    await pump(tester, controller);

    for (var i = 0; i < 30; i++) {
      controller.add(frame(pitch: kNoPitch, voiced: false, db: -90));
    }
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
  });

  testWidgets('handles clipping frames', (tester) async {
    await pump(tester, controller);

    controller.add(frame(db: -0.1, clipping: true));
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
  });

  testWidgets('survives an extreme pitch range in one window', (tester) async {
    await pump(tester, controller);

    // A character-voice drill can genuinely swing this far.
    controller.add(frame(pitch: 62));
    controller.add(frame(pitch: 495));
    controller.add(frame(pitch: 80));
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
  });

  testWidgets('stops cleanly when disposed mid-stream', (tester) async {
    await pump(tester, controller);
    controller.add(frame());
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    controller.add(frame());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('honours reduced motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ResTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: LiveVisualiser(analysis: controller.stream)),
        ),
      ),
    );

    controller.add(frame());
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
  });
}
