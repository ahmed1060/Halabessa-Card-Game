import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/widgets/loading_screen.dart';

void main() {
  testWidgets('startup brand stays static and progress stays bounded', (
    tester,
  ) async {
    final progress = StreamController<double>(sync: true);
    await tester.pumpWidget(
      MaterialApp(home: LoadingScreen(progressStream: progress.stream)),
    );
    progress.add(2);
    await tester.pump();
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      1,
    );
    expect(find.byType(AnimatedSwitcher), findsNothing);
    expect(find.textContaining('PHYSICS'), findsNothing);
    progress.add(double.nan);
    await tester.pump();
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    unawaited(progress.close());
    await tester.pump();
  });
}
