import 'package:flutter_test/flutter_test.dart';
// Reuse the deterministic clock already supplied by Flutter's test SDK.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:halabessa/features/game/presentation/providers/visual_action_queue.dart';

void main() {
  test('dependent artwork serializes without writing any domain state', () {
    fakeAsync((clock) {
      final beats = <String>[];
      final queue = VisualActionQueue<String>(
        onStart: (a) => beats.add(a.value),
        onFinish: (_, __) {},
      );
      queue.add(const VisualAction('1', 'flight', Duration(milliseconds: 220)));
      queue.add(
        const VisualAction('2', 'collect', Duration(milliseconds: 400)),
      );
      expect(beats, ['flight']);
      clock.elapse(const Duration(milliseconds: 219));
      expect(beats, ['flight']);
      clock.elapse(const Duration(milliseconds: 1));
      expect(beats, ['flight', 'collect']);
      clock.elapse(const Duration(milliseconds: 400));
      expect(queue.active, isNull);
      queue.dispose();
    });
  });
  test(
    'ACK identity and generation prevent duplicates and stale completion',
    () {
      fakeAsync((_) {
        final queue = VisualActionQueue<int>(
          onStart: (_) {},
          onFinish: (_, __) {},
        );
        const first = VisualAction('same-card', 1, Duration(seconds: 1));
        expect(queue.add(first), isTrue);
        expect(queue.add(first), isFalse);
        final generation = queue.generation;
        expect(queue.complete('wrong', generation), isFalse);
        queue.reset();
        queue.add(first);
        expect(queue.complete(first.id, generation), isFalse);
        expect(queue.complete(first.id, queue.generation), isTrue);
        queue.dispose();
      });
    },
  );
  test('overflow collapses backlog and disposal cancels every watchdog', () {
    fakeAsync((clock) {
      var overflow = 0, finished = 0;
      final queue = VisualActionQueue<int>(
        capacity: 1,
        onStart: (_) {},
        onFinish: (_, __) => finished++,
        onOverflow: () => overflow++,
      );
      queue.add(const VisualAction('1', 1, Duration(seconds: 1)));
      queue.add(const VisualAction('2', 2, Duration(seconds: 1)));
      expect(
        queue.add(const VisualAction('3', 3, Duration(seconds: 1))),
        isFalse,
      );
      expect(overflow, 1);
      expect(queue.pendingCount, 0);
      expect(queue.active, isNull);
      queue.dispose();
      clock.elapse(const Duration(seconds: 10));
      expect(finished, 0);
      expect(queue.add(const VisualAction('4', 4, Duration.zero)), isFalse);
    });
  });
}
