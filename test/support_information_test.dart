import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/widgets/account_information_screen.dart';

void main() {
  testWidgets(
    'support identifies approved publisher and copies only public contact',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData')
            copied = (call.arguments as Map)['text'] as String;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(home: AccountInformationScreen(support: true)),
      );
      expect(find.text('WeirdPuzz · weirdpuzz@gmail.com'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pump();
      expect(copied, 'weirdpuzz@gmail.com');
      expect(tester.takeException(), isNull);
    },
  );
}
