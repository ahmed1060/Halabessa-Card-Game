import 'dart:math' as math;

/// Quantized physical width avoids a fresh cache entry for tiny viewport
/// changes. The upper bound limits native background texture allocations.
int backgroundDecodeWidth(double logicalWidth, double devicePixelRatio) {
  if (!logicalWidth.isFinite ||
      !devicePixelRatio.isFinite ||
      logicalWidth <= 0 ||
      devicePixelRatio <= 0)
    return 2048;
  return math.min(
    2048,
    math.max(256, ((logicalWidth * devicePixelRatio) / 64).ceil() * 64),
  );
}
