// Actual widgets, deterministic local review only. No gameplay/room injection.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as cards;
import 'package:halabessa/features/game/domain/models/capture.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/presentation/widgets/round_summary_panel.dart';
import 'package:halabessa/features/game/presentation/widgets/match_result_view.dart';
import 'package:halabessa/features/game/presentation/widgets/match_phase_panel.dart';
import 'package:halabessa/features/game/presentation/widgets/option_b_table.dart';
import 'package:halabessa/features/game/presentation/widgets/dealer_seat.dart';
import 'package:halabessa/features/game/presentation/widgets/lantern_card_art.dart';
import 'package:halabessa/features/game/presentation/widgets/table_style.dart';

class _Loader extends AssetLoader {
  final Map<String, dynamic> data;
  const _Loader(this.data);
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => data;
}

void main() {
  for (final size in [const Size(1004, 430), const Size(430, 932)]) {
    for (final scenario in ['round', 'final', 'cut', 'shuffle']) {
      testWidgets('approved $scenario $size', (tester) async {
        SharedPreferences.setMockInitialValues({});
        await EasyLocalization.ensureInitialized();
        final translations =
            jsonDecode(
                  (await tester.runAsync(
                    () =>
                        rootBundle.loadString('assets/translations/ar-EG.json'),
                  ))!,
                )
                as Map<String, dynamic>;
        await tester.runAsync(() async {
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
          for (final entry in {
            'LanternText': 'Cairo.ttf',
            'LanternArabic': 'Cairo.ttf',
            'LanternDisplay': 'Righteous-Regular.ttf',
          }.entries) {
            await (FontLoader(
              entry.key,
            )..addFont(rootBundle.load('assets/fonts/${entry.value}'))).load();
          }
        });
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('ar', 'EG')],
            startLocale: const Locale('ar', 'EG'),
            saveLocale: false,
            path: 'assets/translations',
            assetLoader: _Loader(translations),
            child: Builder(
              builder: (context) => MaterialApp(
                theme: ThemeConfig.darkTheme,
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                home: RepaintBoundary(
                  key: key,
                  child: _Preview(scenario: scenario, size: size),
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 8; i++) {
          await tester.pump();
          await tester.runAsync(
            () async => Future<void>.delayed(const Duration(milliseconds: 70)),
          );
        }
        expect(tester.takeException(), isNull);
        if (scenario == 'shuffle') {
          expect(find.text('خلط الورق'), findsOneWidget);
          // Legal cut stays enabled during a cosmetic shuffle.
          expect(
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNotNull,
          );
        }
        if (scenario == 'final') {
          expect(find.text('43'), findsOneWidget);
          expect(find.text('26'), findsOneWidget);
          expect(find.text('bot_name_template'), findsNothing);
        }
        if (const bool.fromEnvironment('APPROVED_PANELS_REFERENCE')) {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1.5);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final folder = Directory('build/design-review')
              ..createSync(recursive: true);
            await File(
              '${folder.path}/approved-$scenario-${size.width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}

class _Preview extends StatelessWidget {
  final String scenario;
  final Size size;
  const _Preview({required this.scenario, required this.size});
  Widget _players(List<int> ids, Color color) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (final id in ids)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                child: ClipOval(
                  child: Image.asset(
                    id == 2
                        ? 'assets/images/avatars/lantern_partner_v1.png'
                        : id == 1
                        ? 'assets/images/avatars/lantern_rival_woman_v1.png'
                        : 'assets/images/avatars/lantern_rival_man_v1.png',
                  ),
                ),
              ),
              Text(id == 0 ? 'أنت' : 'بوت $id', style: TableStyle.detail),
            ],
          ),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    if (scenario == 'final') {
      return MatchResultView(
        title: 'هزيمة',
        subtitle: 'معلش، المرة الجاية أحسن',
        firstTeam: 'فريقنا',
        secondTeam: 'الفريق الثاني',
        firstScore: 26,
        secondScore: 43,
        firstWon: false,
        firstPlayers: _players([0, 2], TableStyle.mint),
        secondPlayers: _players([1, 3], TableStyle.red),
        stars: 0,
        coins: 0,
        starsLabel: 'نجوم',
        coinsLabel: 'عملات',
        homeLabel: 'الرئيسية',
        replayLabel: 'العب تاني',
        onHome: () => false,
        onReplay: () => false,
      );
    }
    const card = cards.Card(cards.Suit.clubs, cards.Rank.ace);
    final summary = MatchState(
      id: 'OFFLINE_VISUAL_ONLY',
      mode: GameMode.classic,
      playerIds: const ['a', 'b', 'c', 'd'],
      phase: GamePhase.roundScoring,
      dealerIndex: 0,
      currentTurnIndex: 0,
      teamAScore: 14,
      teamBScore: 16,
      phaseStartedAt: DateTime.now(),
      harvestStacks: {
        'teamA': [
          for (var i = 0; i < 5; i++)
            Capture(
              leadingCard: card,
              capturedCards: List.filled(i == 4 ? 10 : 6, card),
              awardedPoints: 1,
            ),
        ],
        'teamB': [
          Capture(
            leadingCard: card,
            capturedCards: List.filled(12, card),
            awardedPoints: 1,
          ),
        ],
      },
    );
    final deckPhase = scenario == 'cut' || scenario == 'shuffle';
    return Scaffold(
      backgroundColor: TableStyle.felt,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            size.width > size.height
                ? 'assets/images/tables/halabessa_tabletop_landscape_v1.png'
                : 'assets/images/tables/halabessa_tabletop_portrait_v1.png',
            fit: BoxFit.fill,
          ),
          if (!deckPhase)
            RoundSummaryPanel(state: summary, firstIsA: true)
          else
            OptionBTable(
              local: _players([0], TableStyle.mint),
              partner: _players([2], TableStyle.mint),
              left: _players([3], TableStyle.red),
              right: _players([1], TableStyle.red),
              scores: const SizedBox(),
              history: const SizedBox(),
              menu: const SizedBox(),
              ourPile: const SizedBox(),
              rivalPile: const SizedBox(),
              board: const SizedBox(),
              hand: const SizedBox(),
              showPhase: true,
              deckSidePhase: true,
              deck: DealDeck(
                remaining: 52,
                label: 'ورق التوزيع',
                thematic: true,
                shuffleIdentity: scenario == 'shuffle' ? 'visual-only' : null,
                backBuilder: (w, h) => LanternCardArt(
                  card: card,
                  faceUp: false,
                  width: w,
                  height: h,
                ),
              ),
              phase: MatchPhasePanel(
                title: 'القطعة',
                message: 'دورك تقطع الكوتشينة!',
                failureMessage: 'حاول تاني',
                actionLabel: 'اقطع الورق',
                onAction: () async {},
                deckSide: true,
                shuffleIntro: scenario == 'shuffle',
                shuffleTitle: 'خلط الورق',
                shuffleMessage: 'جاري خلط الكوتشينة…',
                shuffleNext: 'القطع ثم التوزيع تلقائيًا',
              ),
            ),
        ],
      ),
    );
  }
}
