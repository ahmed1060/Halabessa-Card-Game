import 'dart:async';
import 'dart:collection';

/// Rebuild with false to restore the existing artwork/snapshot paths. No domain
/// or backend flag is changed by this presentation-only switch.
const cardJuiceEnabled = bool.fromEnvironment(
  'HALABESSA_CARD_JUICE',
  defaultValue: true,
);

class VisualAction<T> {
  final String id;
  final T value;
  final Duration duration;
  const VisualAction(this.id, this.value, this.duration);
}

/// Serializes artwork, not commands. Completion and watchdogs have no reference
/// to game providers, rules, scores or deadlines.
class VisualActionQueue<T> {
  final void Function(VisualAction<T>) onStart;
  final void Function(VisualAction<T>, bool timedOut) onFinish;
  final void Function()? onOverflow;
  final Duration allowance;
  final int capacity;
  final _pending = Queue<VisualAction<T>>();
  final _seen = <String>{};
  Timer? _timer;
  VisualAction<T>? _active;
  int _generation = 0;
  bool _disposed = false;
  VisualActionQueue({
    required this.onStart,
    required this.onFinish,
    this.onOverflow,
    this.allowance = Duration.zero,
    this.capacity = 8,
  });
  int get generation => _generation;
  VisualAction<T>? get active => _active;
  int get pendingCount => _pending.length;

  bool add(VisualAction<T> action) {
    if (_disposed || !_seen.add(action.id)) return false;
    while (_seen.length > 256) {
      _seen.remove(_seen.first);
    }
    if (_pending.length >= capacity) {
      reset();
      onOverflow?.call();
      return false;
    }
    _pending.add(action);
    _next();
    return true;
  }

  void _next() {
    if (_disposed || _active != null || _pending.isEmpty) return;
    final action = _active = _pending.removeFirst();
    final generation = _generation;
    _timer = Timer(action.duration + allowance, () {
      if (generation == _generation) {
        complete(action.id, generation, timedOut: true);
      }
    });
    try {
      onStart(action);
    } catch (_) {
      // A renderer failure may skip artwork, never a valid gameplay action.
      complete(action.id, generation, timedOut: true);
    }
  }

  bool complete(String id, int generation, {bool timedOut = false}) {
    if (_disposed || generation != _generation || _active?.id != id) {
      return false;
    }
    _timer?.cancel();
    final action = _active!;
    _active = null;
    try {
      onFinish(action, timedOut);
    } finally {
      _next();
    }
    return true;
  }

  void reset({Iterable<String> alreadySeen = const []}) {
    _generation++;
    _timer?.cancel();
    _active = null;
    _pending.clear();
    _seen.clear();
    _seen.addAll(alreadySeen.take(256));
  }

  void dispose() {
    reset();
    _disposed = true;
  }
}
