import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game;
import 'package:halabessa/features/game/domain/models/capture.dart';
import 'package:halabessa/features/game/presentation/widgets/team_capture_stack.dart';
import 'package:halabessa/features/game/presentation/widgets/dealer_seat.dart';
import 'package:halabessa/features/game/presentation/widgets/match_table_layout.dart';
import 'package:halabessa/features/game/presentation/widgets/table_seat.dart';
import 'package:halabessa/features/game/presentation/widgets/deal_card_motion.dart';
import 'package:halabessa/features/game/presentation/widgets/board_card_motion.dart';

const first = game.Card(game.Suit.hearts, game.Rank.king);
const second = game.Card(game.Suit.clubs, game.Rank.eight);
const hidden = game.Card(game.Suit.spades, game.Rank.two);
Widget face(game.Card card, double width, double height) => SizedBox(
  key: ValueKey('face-${card.firebaseKey}'),
  width: width,
  height: height,
);
Widget back(double width, double height) =>
    SizedBox(key: const ValueKey('hidden-back'), width: width, height: height);

void main() {
  test('round-end awards preserve counts but are not played capture cards', () {
    const award = Capture(
      leadingCard: hidden,
      capturedCards: [second],
      isRoundAward: true,
    );
    expect(Capture.fromJson(award.toJson()).isRoundAward, isTrue);
    expect(award.cardCount, 2);
    expect(
      Capture.fromJson(
        const Capture(leadingCard: first, capturedCards: []).toJson(),
      ).isRoundAward,
      isFalse,
    );
    expect(Capture.fromJson({'capturedCards': []}).isRoundAward, isTrue);
  });

  testWidgets('history renders only played capture cards in order and clears', (
    tester,
  ) async {
    Widget history(List<Capture> captures) => MaterialApp(
      home: Scaffold(
        body: CaptureCardHistory(
          captures: captures,
          title: 'Capture cards',
          explanation: 'This round only',
          emptyLabel: 'No captures',
          faceBuilder: face,
          cardLabel: (card) => card.firebaseKey,
        ),
      ),
    );
    await tester.pumpWidget(
      history(const [
        Capture(leadingCard: first, capturedCards: [hidden]),
        Capture(leadingCard: second, capturedCards: [hidden]),
        Capture(leadingCard: hidden, capturedCards: [], isRoundAward: true),
      ]),
    );
    expect(find.byKey(ValueKey('face-${first.firebaseKey}')), findsOneWidget);
    expect(find.byKey(ValueKey('face-${second.firebaseKey}')), findsOneWidget);
    expect(find.byKey(ValueKey('face-${hidden.firebaseKey}')), findsNothing);
    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('Back to table'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    expect(
      tester.getCenter(find.text('1')).dx,
      lessThan(tester.getCenter(find.text('2')).dx),
    );
    await tester.pumpWidget(history(const []));
    expect(find.byKey(ValueKey('face-${first.firebaseKey}')), findsNothing);
    expect(find.text('No captures'), findsOneWidget);
  });

  testWidgets('team pile caps its layers and latest face stays beside it', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TeamCaptureStack(
              captures: [
                for (var i = 0; i < 24; i++)
                  const Capture(leadingCard: first, capturedCards: [hidden]),
              ],
              label: 'Our team',
              countLabel: '48 cards',
              latestLabel: 'Last capture',
              historyLabel: 'View history',
              faceBuilder: face,
              backBuilder: back,
              onHistory: () => taps++,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('hidden-back')), findsNWidgets(6));
    expect(find.byKey(ValueKey('face-${hidden.firebaseKey}')), findsNothing);
    final pile = tester.getRect(find.byType(FaceDownStack));
    final latest = tester.getRect(
      find.byKey(ValueKey('face-${first.firebaseKey}')),
    );
    expect(pile.overlaps(latest), isFalse);
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    expect(taps, 1);
  });

  testWidgets('rival pile never displays a capture face', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TeamCaptureStack(
              captures: const [
                Capture(leadingCard: first, capturedCards: [hidden]),
              ],
              label: 'Rivals',
              countLabel: '2 cards',
              latestLabel: '',
              historyLabel: '',
              showLatest: false,
              faceBuilder: face,
              backBuilder: back,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(ValueKey('face-${first.firebaseKey}')), findsNothing);
    expect(find.byType(InkWell), findsOneWidget);
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1280, 720),
  ]) {
    for (final direction in TextDirection.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'dealer/collections fit ${size.width} ${direction.name} ${scale}x',
          (tester) async {
            await tester.binding.setSurfaceSize(size);
            addTearDown(() => tester.binding.setSurfaceSize(null));
            for (var dealer = 0; dealer < 4; dealer++) {
              Widget seat(int index) => DealerSeat(
                seat: const TableSeat(name: 'Player', detail: 'Cards: 4'),
                isDealer: dealer == index,
                compact: index == 1 || index == 3,
                remaining: 32,
                label: 'Deal deck',
                backBuilder: back,
              );
              await tester.pumpWidget(
                MaterialApp(
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: Directionality(
                      textDirection: direction,
                      child: Scaffold(
                        body: MatchTableLayout(
                          header: const MatchScoreBar(
                            firstLabel: 'Our team',
                            secondLabel: 'Rivals',
                            firstScore: 18,
                            secondScore: 15,
                            details: 'Round 3',
                            roomLabel: 'Practice',
                            onCopyRoom: null,
                          ),
                          partner: seat(2),
                          leftOpponent: seat(3),
                          rightOpponent: seat(1),
                          localSeat: const SizedBox(height: 84),
                          board: const SizedBox(width: 230, height: 200),
                          collections: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TeamCaptureStack(
                                  captures: const [],
                                  label: 'Our team',
                                  countLabel: '0 cards',
                                  latestLabel: 'Last capture',
                                  historyLabel: 'View history',
                                  faceBuilder: face,
                                  backBuilder: back,
                                  onHistory: () {},
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TeamCaptureStack(
                                  captures: const [],
                                  label: 'Rivals',
                                  countLabel: '0 cards',
                                  latestLabel: '',
                                  historyLabel: '',
                                  showLatest: false,
                                  faceBuilder: face,
                                  backBuilder: back,
                                ),
                              ),
                            ],
                          ),
                          status: const Text('Your turn'),
                          hand: const SizedBox(height: 110),
                          controls: const SizedBox(height: 48),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();
              expect(tester.takeException(), isNull, reason: 'dealer $dealer');
            }
          },
        );
      }
    }
  }

  testWidgets('deal flight measures actual deck and respects reduced motion', (
    tester,
  ) async {
    final source = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 20,
                  top: 20,
                  child: SizedBox(key: source, width: 40, height: 60),
                ),
                Positioned(
                  left: 200,
                  top: 300,
                  child: DealCardMotion(
                    sourceKey: source,
                    child: const SizedBox(width: 70, height: 100),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final motion = tester.widget<BoardCardMotion>(find.byType(BoardCardMotion));
    expect(motion.origin, const Offset(-195, -300));
    expect(
      tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(BoardCardMotion),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getTranslation()
          .x,
      0,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
