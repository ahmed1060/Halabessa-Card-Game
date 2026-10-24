// Offline synthesized review candidates only. Never imported by the game.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  final output = Directory('build/sound-review-2026-10-24')..createSync(recursive: true);
  const rate = 44100, samples = 9702;
  for (var variant = 0; variant < 2; variant++) {
    final random = Random(9260 + variant);
    final data = ByteData(44 + samples * 2);
    void text(int at, String value) { for (var i = 0; i < value.length; i++) { data.setUint8(at + i, value.codeUnitAt(i)); } }
    text(0, 'RIFF'); data.setUint32(4, data.lengthInBytes - 8, Endian.little);
    text(8, 'WAVE'); text(12, 'fmt '); data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); data.setUint16(22, 1, Endian.little);
    data.setUint32(24, rate, Endian.little); data.setUint32(28, rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little); data.setUint16(34, 16, Endian.little);
    text(36, 'data'); data.setUint32(40, samples * 2, Endian.little);
    var low = 0.0, paper = 0.0;
    for (var i = 0; i < samples; i++) {
      final t = i / rate, noise = random.nextDouble() * 2 - 1;
      low += .055 * (noise - low);
      paper += .38 * (noise - paper);
      final click = (noise - paper) * exp(-t * 1100) * .65;
      final edge = paper * exp(-pow((t - .007) / .004, 2)) * 1.8;
      final flex = (noise - low) * exp(-t * (variant == 0 ? 95 : 65)) *
          (.14 + .1 * sin(2 * pi * 75 * t));
      final body = (low * 1.6 + sin(2 * pi * (variant == 0 ? 185 : 135) * t) * .16) *
          exp(-t * (variant == 0 ? 70 : 43));
      final sample = ((click + edge + flex + body) * .8).clamp(-.95, .95);
      data.setInt16(44 + i * 2, (sample * 32767).round(), Endian.little);
    }
    final name = variant == 0 ? 'A-dry-paper-edge.wav' : 'B-fuller-table-edge.wav';
    final file = File('${output.path}/$name')..writeAsBytesSync(data.buffer.asUint8List());
    stdout.writeln('${file.absolute.path} (${data.lengthInBytes} bytes, synthesized)');
  }
}
