import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/features/game/domain/models/chat_message.dart';
import 'package:halabessa/features/game/domain/models/quick_chat_phrase.dart';
import 'package:halabessa/features/game/presentation/widgets/chat_overlay.dart';
import 'package:halabessa/features/game/presentation/widgets/table_chat_bubble.dart';
import 'package:halabessa/features/game/presentation/widgets/table_leave_dialog.dart';
import 'package:halabessa/features/home/presentation/pages/admin_quick_chat_screen.dart';

class _Strings extends AssetLoader {
  const _Strings();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(
            File(
              '$path/${locale.languageCode == 'ar' ? 'ar-EG' : 'en-US'}.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
}

const phrase = QuickChatPhrase(
  id: 'nice_play',
  en: 'Nice play!',
  ar: 'لعبة حلوة!',
);
const catalog = QuickChatCatalog(revision: 3, items: [phrase]);
Future<void> host(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en', 'US'),
  Size size = const Size(430, 850),
  bool reduced = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('ar', 'EG')],
      path: 'assets/translations',
      assetLoader: const _Strings(),
      startLocale: locale,
      saveLocale: false,
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          theme: ThemeConfig.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
          home: Scaffold(body: Center(child: child)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  for (final locale in [const Locale('en', 'US'), const Locale('ar', 'EG')]) {
    for (final size in [
      const Size(430, 850),
      const Size(850, 430),
      const Size(320, 300),
    ]) {
      testWidgets('compact locked chat keeps presets and fits $locale $size', (
        tester,
      ) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        var sent = 0;
        await host(
          tester,
          SizedBox(
            width: 340,
            height: size.height < 400 ? 210 : 410,
            child: TableChatPanel(
              controller: controller,
              channel: ChatChannel.public,
              policy: const TableChatPolicy(available: true, catalog: catalog),
              messages: const [],
              onClose: () {},
              onChannel: (_) {},
              onSend: () => fail('locked composer sent text'),
              onQuick: (_) => sent++,
              onRetry: () {},
            ),
          ),
          locale: locale,
          size: size,
        );
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('table-chat-composer')),
              )
              .enabled,
          false,
        );
        expect(find.text('Team'), findsNothing);
        await tester.ensureVisible(
          find.widgetWithText(ActionChip, phrase.label(locale.languageCode)),
        );
        await tester.tap(
          find.widgetWithText(ActionChip, phrase.label(locale.languageCode)),
        );
        expect(sent, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('friends can type; game log has no composer', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    Widget panel(ChatChannel channel) => SizedBox(
      width: 350,
      height: 440,
      child: TableChatPanel(
        controller: controller,
        channel: channel,
        policy: const TableChatPolicy(
          available: true,
          canType: true,
          catalog: catalog,
        ),
        messages: const [],
        onClose: () {},
        onChannel: (_) {},
        onSend: () {},
        onQuick: (_) {},
        onRetry: () {},
      ),
    );
    await host(tester, panel(ChatChannel.public));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('table-chat-composer')))
          .enabled,
      true,
    );
    await host(tester, panel(ChatChannel.game));
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
  });
  testWidgets(
    'avatar bubble fades out and reduced motion replaces immediately',
    (tester) async {
      await host(
        tester,
        const TableChatBubble(message: 'Nice play!', identity: 'one'),
      );
      expect(find.text('Nice play!'), findsOneWidget);
      await host(tester, const TableChatBubble(message: null));
      expect(find.text('Nice play!'), findsNothing);
      await host(
        tester,
        const TableChatBubble(message: 'Hello', identity: 'two'),
        reduced: true,
      );
      expect(
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
        Duration.zero,
      );
    },
  );
  testWidgets('leave is single-submit and keeps failures retryable', (
    tester,
  ) async {
    final completion = Completer<bool>();
    var calls = 0;
    await host(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<bool>(
            context: context,
            builder: (_) => TableLeaveDialog(
              offline: true,
              onLeave: () {
                calls++;
                return completion.future;
              },
            ),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave practice'));
    await tester.pump();
    await tester.tap(find.byType(OutlinedButton));
    expect(calls, 1);
    completion.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Could not leave. Please try again.'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.byType(TableLeaveDialog), findsNothing);
  });
  testWidgets(
    'superadmin manager saves both languages with revision and confirms delete',
    (tester) async {
      Map<String, dynamic>? saved;
      await host(
        tester,
        QuickChatManager(
          catalog: catalog,
          onChange: (body) async {
            saved = body;
            return const QuickChatCatalog(revision: 4, items: []);
          },
        ),
        size: const Size(1000, 850),
      );
      await tester.tap(find.text('Add phrase'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Well played!');
      await tester.enterText(find.byType(TextFormField).at(1), 'لعب جميل!');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(saved?['revision'], 3);
      expect(saved?['phrase'], {'en': 'Well played!', 'ar': 'لعب جميل!'});
      expect(
        find.text('No quick phrases. Add a phrase to get started.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'deleting a quick phrase requires confirmation and preserves cancellation',
    (tester) async {
      Map<String, dynamic>? changed;
      await host(
        tester,
        QuickChatManager(
          catalog: catalog,
          onChange: (body) async {
            changed = body;
            return const QuickChatCatalog(revision: 4, items: []);
          },
        ),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(
        find.text('Removes the preset, not past messages.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep phrase'));
      await tester.pumpAndSettle();
      expect(changed, isNull);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();
      expect(changed, {
        'operation': 'delete',
        'presetId': 'nice_play',
        'revision': 3,
      });
      expect(
        find.text('No quick phrases. Add a phrase to get started.'),
        findsOneWidget,
      );
    },
  );
}
