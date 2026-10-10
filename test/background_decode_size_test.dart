import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/widgets/background_decode_size.dart';

void main() {
  test(
    'background decode size quantizes near-identical views and caps textures',
    () {
      expect(backgroundDecodeWidth(430, 3), 1344);
      expect(backgroundDecodeWidth(431, 3), 1344);
      expect(backgroundDecodeWidth(932, 3), 2048);
      expect(backgroundDecodeWidth(10000, 5), 2048);
      expect(backgroundDecodeWidth(32, 1), 256);
      expect(backgroundDecodeWidth(double.infinity, 3), 2048);
      expect(backgroundDecodeWidth(400, 0), 2048);
    },
  );
}
