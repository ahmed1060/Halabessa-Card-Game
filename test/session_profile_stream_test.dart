import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/features/auth/data/repositories/session_profile_stream.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'logout is delivered without waiting for an endless profile stream',
    () async {
      final auth = StreamController<String?>();
      final profile = StreamController<String?>();
      final values = <String?>[];
      final errors = <Object>[];
      final subscription = sessionProfileStream(
        auth.stream,
        (_) => profile.stream,
      ).listen(values.add, onError: errors.add);
      auth.add('alice');
      await flush();
      profile.add('Alice');
      await flush();
      auth.add(null);
      await flush();
      profile.addError(StateError('permission-denied'));
      profile.add('stale Alice');
      await flush();
      expect(values, ['Alice', null]);
      expect(errors, isEmpty);
      expect(profile.hasListener, isFalse);
      await subscription.cancel();
      await auth.close();
      await profile.close();
    },
  );

  test(
    'pending enrichment and cancellation cannot delay logout or leak old data',
    () async {
      final auth = StreamController<String?>();
      final pending = Completer<String?>();
      final values = <String?>[];
      final errors = <Object>[];
      final subscription = sessionProfileStream(
        auth.stream,
        (_) => Stream.fromFuture(pending.future),
      ).listen(values.add, onError: errors.add);
      auth.add('alice');
      await flush();
      auth.add(null);
      await flush();
      expect(values, [null]);
      pending.completeError(StateError('permission-denied'));
      await flush();
      expect(values, [null]);
      expect(errors, isEmpty);
      await subscription.cancel();
      await auth.close();
    },
  );

  test(
    'switching accounts cancels the previous listener and keeps live errors visible',
    () async {
      final auth = StreamController<String?>();
      final alice = StreamController<String?>();
      final bob = StreamController<String?>();
      final values = <String?>[];
      final errors = <Object>[];
      final subscription = sessionProfileStream(
        auth.stream,
        (uid) => uid == 'alice' ? alice.stream : bob.stream,
      ).listen(values.add, onError: errors.add);
      auth.add('alice');
      await flush();
      auth.add('bob');
      await flush();
      alice.add('wrong account');
      bob.add('Bob');
      bob.addError(StateError('real-profile-failure'));
      await flush();
      expect(values, ['Bob']);
      expect(errors.single, isA<StateError>());
      await subscription.cancel();
      expect(auth.hasListener, isFalse);
      expect(bob.hasListener, isFalse);
      await auth.close();
      await alice.close();
      await bob.close();
    },
  );
}
