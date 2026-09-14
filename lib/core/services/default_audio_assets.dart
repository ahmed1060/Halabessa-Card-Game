import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Procedural offline audio engine for Halabessa.
/// Generates crisp, zero-dependency Base64 Data URI sound effects (WAV format)
/// in-memory so the game never requires external network assets for basic feedback.
class DefaultAudioAssets {
  static final Map<String, String> _cache = {};

  static String? getSfx(String assetPath) {
    if (_cache.containsKey(assetPath)) {
      return _cache[assetPath];
    }

    final generated = _generateSfx(assetPath);
    if (generated != null) {
      _cache[assetPath] = generated;
    }
    return generated;
  }

  static String? _generateSfx(String assetPath) {
    switch (assetPath) {
      case 'sfx/play.mp3':
        // Crisp card snap on felt table: short noise burst with steep exponential decay
        return _synthesize(durationSeconds: 0.08, generator: (t) {
          final decay = exp(-t * 60);
          final noise = (Random().nextDouble() * 2 - 1) * 0.7;
          final tone = sin(2 * pi * 320 * t) * 0.3;
          return (noise + tone) * decay;
        });

      case 'sfx/deal.mp3':
        // Card whoosh / slide: rising gentle noise sweep
        return _synthesize(durationSeconds: 0.12, generator: (t) {
          final progress = t / 0.12;
          final envelope = sin(pi * progress);
          final freq = 400 + progress * 600;
          final noise = (Random().nextDouble() * 2 - 1) * 0.4;
          return (sin(2 * pi * freq * t) * 0.6 + noise) * envelope * 0.5;
        });

      case 'sfx/capture.mp3':
        // Capture / sweep: bright ascending chime
        return _synthesize(durationSeconds: 0.28, generator: (t) {
          final decay = exp(-t * 12);
          final f1 = sin(2 * pi * 523.25 * t); // C5
          final f2 = sin(2 * pi * 659.25 * t); // E5
          final f3 = sin(2 * pi * 783.99 * t); // G5
          final f4 = sin(2 * pi * 1046.50 * t); // C6
          return (f1 * 0.3 + f2 * 0.3 + f3 * 0.25 + f4 * 0.25) * decay;
        });

      case 'sfx/shuffle.mp3':
        // Card riffle flutter: rapid micro-ticks
        return _synthesize(durationSeconds: 0.35, generator: (t) {
          final tick = sin(2 * pi * 25 * t);
          final envelope = sin(pi * (t / 0.35));
          final noise = (Random().nextDouble() * 2 - 1) * (tick > 0.4 ? 0.9 : 0.1);
          return noise * envelope * 0.6;
        });

      case 'sfx/cut.mp3':
        // Deck cut thud: low knock
        return _synthesize(durationSeconds: 0.10, generator: (t) {
          final decay = exp(-t * 45);
          final low = sin(2 * pi * 140 * t) * 0.8;
          final sub = sin(2 * pi * 70 * t) * 0.5;
          return (low + sub) * decay;
        });

      case 'sfx/win.mp3':
        // Victory fanfare: bright ascending triad
        return _synthesize(durationSeconds: 0.65, generator: (t) {
          double freq = 523.25; // C5
          if (t > 0.15) freq = 659.25; // E5
          if (t > 0.30) freq = 783.99; // G5
          if (t > 0.45) freq = 1046.50; // C6
          final noteTime = t % 0.15;
          final decay = exp(-noteTime * 10);
          final harmonic = sin(2 * pi * freq * 2 * t) * 0.2;
          return (sin(2 * pi * freq * t) * 0.8 + harmonic) * decay * 0.7;
        });

      case 'sfx/lose.mp3':
        // Defeat tone: descending minor chime
        return _synthesize(durationSeconds: 0.45, generator: (t) {
          final progress = t / 0.45;
          final freq = 380 - progress * 140;
          final decay = exp(-t * 7);
          return sin(2 * pi * freq * t) * decay * 0.6;
        });

      case 'sfx/purchase.mp3':
        // Coin clink: dual high pitch bells
        return _synthesize(durationSeconds: 0.25, generator: (t) {
          final decay = exp(-t * 18);
          final bell1 = sin(2 * pi * 1567.98 * t) * 0.6; // G6
          final bell2 = sin(2 * pi * 2093.00 * t) * 0.4; // C7
          return (bell1 + bell2) * decay;
        });

      default:
        return null;
    }
  }

  /// Synthesizes 16-bit Mono PCM WAV audio and returns a Data URI.
  static String _synthesize({
    required double durationSeconds,
    required double Function(double t) generator,
    int sampleRate = 22050,
  }) {
    final int numSamples = (durationSeconds * sampleRate).toInt();
    final int byteRate = sampleRate * 2;
    final int dataChunkSize = numSamples * 2;
    final int totalFileSize = 36 + dataChunkSize;

    final bytes = ByteData(44 + dataChunkSize);

    // RIFF chunk descriptor
    bytes.setUint8(0, 0x52); // 'R'
    bytes.setUint8(1, 0x49); // 'I'
    bytes.setUint8(2, 0x46); // 'F'
    bytes.setUint8(3, 0x46); // 'F'
    bytes.setUint32(4, totalFileSize, Endian.little);
    bytes.setUint8(8, 0x57);  // 'W'
    bytes.setUint8(9, 0x41);  // 'A'
    bytes.setUint8(10, 0x56); // 'V'
    bytes.setUint8(11, 0x45); // 'E'

    // "fmt " sub-chunk
    bytes.setUint8(12, 0x66); // 'f'
    bytes.setUint8(13, 0x6D); // 'm'
    bytes.setUint8(14, 0x74); // 't'
    bytes.setUint8(15, 0x20); // ' '
    bytes.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    bytes.setUint16(20, 1, Endian.little);  // AudioFormat (1 = PCM)
    bytes.setUint16(22, 1, Endian.little);  // NumChannels (1 = Mono)
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, byteRate, Endian.little);
    bytes.setUint16(32, 2, Endian.little);  // BlockAlign (NumChannels * BitsPerSample/8)
    bytes.setUint16(34, 16, Endian.little); // BitsPerSample (16 bits)

    // "data" sub-chunk
    bytes.setUint8(36, 0x64); // 'd'
    bytes.setUint8(37, 0x61); // 'a'
    bytes.setUint8(38, 0x74); // 't'
    bytes.setUint8(39, 0x61); // 'a'
    bytes.setUint32(40, dataChunkSize, Endian.little);

    // Write samples
    int byteOffset = 44;
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double sample = generator(t).clamp(-1.0, 1.0);
      final int pcm16 = (sample * 32767).toInt().clamp(-32768, 32767);
      bytes.setInt16(byteOffset, pcm16, Endian.little);
      byteOffset += 2;
    }

    final uint8List = bytes.buffer.asUint8List();
    final base64String = base64Encode(uint8List);
    return 'data:audio/wav;base64,$base64String';
  }
}
