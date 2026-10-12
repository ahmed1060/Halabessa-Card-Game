import 'package:flutter/foundation.dart';

/// Presentation/request hints only; the trusted server still owns deadlines.
/// After calibration, elapsed time is monotonic across device wall-clock edits.
class OnlineMatchClock extends ChangeNotifier {
  static final instance = OnlineMatchClock();
  final DateTime Function() _wall;
  late final Duration Function() _elapsed;
  DateTime? _anchor;
  Duration _anchorElapsed = Duration.zero;
  OnlineMatchClock({DateTime Function()? wall, Duration Function()? elapsed})
    : _wall = wall ?? DateTime.now {
    final watch = Stopwatch()..start();
    _elapsed = elapsed ?? (() => watch.elapsed);
  }
  DateTime now() =>
      _anchor == null ? _wall() : _anchor!.add(_elapsed() - _anchorElapsed);

  void calibrate(Object? offsetMilliseconds) {
    if (offsetMilliseconds is! num ||
        !offsetMilliseconds.isFinite ||
        offsetMilliseconds.abs() > 3155760000000)
      return; // Bound integer conversion to 100 years.
    DateTime candidate;
    try {
      candidate = _wall().add(
        Duration(milliseconds: offsetMilliseconds.round()),
      );
    } catch (_) {
      return;
    }
    _anchor = candidate;
    _anchorElapsed = _elapsed();
    notifyListeners();
  }
}
