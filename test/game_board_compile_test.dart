import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/game/presentation/pages/game_board_screen.dart';

void main() {
  // Keep the production page in the test compilation graph. Isolated results
  // widget tests alone cannot catch invalid callbacks in its owning screen.
  test('production game board compiles alongside UI regression tests', () {
    expect(const GameBoardScreen().createState(), isNotNull);
  });
}
