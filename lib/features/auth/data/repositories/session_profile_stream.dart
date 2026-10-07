import 'dart:async';

/// A profile subscription must never pause delivery of authentication changes.
/// Old listeners (including pending async enrichment) cannot publish after a
/// sign-out/account switch, even if cancelling their subscription is delayed.
Stream<P?> sessionProfileStream<A, P>(
  Stream<A?> sessions,
  Stream<P?> Function(A account) profiles,
) {
  late StreamController<P?> output;
  StreamSubscription<A?>? auth;
  StreamSubscription<P?>? profile;
  var generation = 0;
  var cancelled = false;
  var authDone = false;
  var profileDone = true;

  void closeIfDone() {
    if (!cancelled && authDone && profileDone) output.close();
  }

  output = StreamController<P?>(
    onListen: () {
      auth = sessions.listen(
        (account) {
          final current = ++generation;
          final previous = profile;
          profile = null;
          profileDone = true;
          // Cancellation of an asyncMap can wait for an outstanding network
          // request. Do not await it before delivering the signed-out state.
          if (previous != null) {
            unawaited(previous.cancel().catchError((Object _) {}));
          }
          if (account == null) {
            output.add(null);
            return;
          }
          try {
            profileDone = false;
            profile = profiles(account).listen(
              (value) {
                if (!cancelled && current == generation) output.add(value);
              },
              onError: (Object error, StackTrace stack) {
                if (!cancelled && current == generation) {
                  output.addError(error, stack);
                }
              },
              onDone: () {
                if (current != generation) return;
                profileDone = true;
                closeIfDone();
              },
            );
          } catch (error, stack) {
            profileDone = true;
            output.addError(error, stack);
          }
        },
        onError: output.addError,
        onDone: () {
          authDone = true;
          closeIfDone();
        },
      );
    },
    onCancel: () async {
      cancelled = true;
      generation++;
      await Future.wait([
        if (auth != null) auth!.cancel(),
        if (profile != null) profile!.cancel(),
      ]);
    },
  );
  return output.stream;
}
