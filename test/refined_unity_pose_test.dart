import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:halabessa/features/game/presentation/providers/unity_visual_presentation.dart';
import 'package:halabessa/features/game/presentation/widgets/hand_card_placement.dart';
import 'unity_visual_presentation_test.dart' as fixture;

void main() {
  test('refined poses stay private, replay after other actions and clear on scope change', () {
    fakeAsync((clock) {
      final sent = <Map<String, dynamic>>[];
      final visual = UnityVisualPresentation(send: sent.add, onContact: (_, __) {});
      visual.negotiate(1, interactions: true, refinedHand: true);
      visual.accept(fixture.state(1), 'a', active: true, reduced: false, interactions: true);
      visual.updateHandPose('clubs_six', false, -.3, 0);
      final count = sent.length;
      visual.updateHandPose('hearts_king', true, -.3, 0);
      expect(sent.length, count, reason: 'no opponent private pose');
      visual.accept(fixture.state(2, play: true), 'a', active: true, reduced: false, interactions: true);
      expect(sent.last['type'], 'HAND_POSE');
      expect(sent.last['cardId'], 'clubs_six');
      final action = sent.lastWhere((m) => m['type'] == 'VISUAL_ACTION');
      if (cardUiRefinements) {
        expect(action['refinedHand'], true);
        expect((action['handPoses'] as List).single['cardId'], 'clubs_six');
      }
      visual.accept(fixture.state(3, round: 2), 'a', active: true, reduced: false, interactions: true);
      if (cardUiRefinements) expect(sent.last['handPoses'], isEmpty);
      visual.dispose();
    });
  });
  test('legacy export does not receive refined snapshot fields', () {
    final sent = <Map<String, dynamic>>[];
    final visual = UnityVisualPresentation(send: sent.add, onContact: (_, __) {});
    visual.negotiate(1, interactions: true);
    visual.accept(fixture.state(1), 'a', active: true, reduced: false, interactions: true);
    expect(sent.last.containsKey('refinedHand'), false);
    expect(sent.last.containsKey('handPoses'), false);
    visual.dispose();
  });
}
