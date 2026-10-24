// Review artifacts only. Does not register sounds or write application settings.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:halabessa/core/services/default_audio_assets.dart';

const reviewDirectory = 'build/sound-options-2026-10-24';
const extraChoices = <String, List<String>>{
  'pick': ['Rounded paper pinch', 'Fine corner click', 'Quiet fingertip lift'],
  'return': ['Low felt swish', 'Short reverse flick', 'Quiet velvet brush'],
  'play': ['Warm wooden contact', 'Double paper tick', 'Muted felt landing'],
  'deal': ['Brushed paper glide', 'Fast zipper flick', 'Quiet single slide'],
  'reveal': ['Soft turn and wood tap', 'Bright flip and tick', 'Whisper turn'],
  'slam': [
    'Hollow wood and paper edge',
    'Sharp double flex',
    'Low padded edge',
  ],
  'capture': [
    'Gather and wooden settle',
    'Bright three-note reward',
    'Quiet stack sweep',
  ],
  'shuffle': [
    'Loose packet shuffle',
    'Rapid bridge flutter',
    'Soft continuous mix',
  ],
  'cut': [
    'Wooden packet exchange',
    'Crisp triple settle',
    'Quiet low stack tap',
  ],
  'win': [
    'Modal rising plucks',
    'Bright bell celebration',
    'Quiet resolved chord',
  ],
  'lose': [
    'Warm low reflection',
    'Short descending bells',
    'Quiet single resolve',
  ],
  'purchase': [
    'Rounded token pair',
    'Bright reward sparkle',
    'Quiet soft confirmation',
  ],
  'home-music': [
    'Moonlit modal plucks',
    'Lantern cafe pulse',
    'Still courtyard pad',
  ],
  'room-music': ['Low modal plucks', 'Soft table pulse', 'Quiet night air'],
};
const events = <Map<String, Object>>[
  {
    'id': 'pick',
    'title': 'Pick up a card',
    'group': 'Card handling',
    'when': 'Touch or grab a card; also the deck separating.',
    'a': 'Soft paper lift',
    'b': 'Crisp corner flick',
    'seconds': .08,
  },
  {
    'id': 'return',
    'title': 'Return / rejected move',
    'group': 'Card handling',
    'when':
        'A rejected move returns. A private queue cancellation stays silent.',
    'a': 'Felt slide back',
    'b': 'Soft paper brush',
    'seconds': .18,
  },
  {
    'id': 'play',
    'title': 'Normal card play',
    'group': 'Card handling',
    'when': 'An ordinary card contacts the table; also reused by emotes.',
    'a': 'Dry felt tap',
    'b': 'Crisp card snap',
    'seconds': .15,
  },
  {
    'id': 'deal',
    'title': 'Deal a card',
    'group': 'Card handling',
    'when': 'Cards leave the deal deck.',
    'a': 'Single paper flick',
    'b': 'Two-stage slide',
    'seconds': .19,
  },
  {
    'id': 'reveal',
    'title': 'Public reveal',
    'group': 'Card handling',
    'when': 'A public reveal lands beside the hand, without playing the card.',
    'a': 'Lift and soft land',
    'b': 'Airy paper turn',
    'seconds': .25,
  },
  {
    'id': 'slam',
    'title': 'Special slam',
    'group': 'Card handling',
    'when': 'Special slam contact. Current is your approved dry paper-edge A.',
    'a': 'Softer dry edge',
    'b': 'Firmer table edge',
    'seconds': .22,
  },
  {
    'id': 'capture',
    'title': 'Collect / capture',
    'group': 'Table and deck',
    'when':
        'A capture or special winning collection; separate from the slam strike.',
    'a': 'Paper sweep',
    'b': 'Warm collection accent',
    'seconds': .34,
  },
  {
    'id': 'shuffle',
    'title': 'Shuffle the deck',
    'group': 'Table and deck',
    'when': 'The deck is being mixed.',
    'a': 'Tight riffle',
    'b': 'Overhand packets',
    'seconds': .48,
  },
  {
    'id': 'cut',
    'title': 'Cut / deck contact',
    'group': 'Table and deck',
    'when':
        'Cut packets reunite; also the shuffle deck returning to its place.',
    'a': 'Two packet taps',
    'b': 'Single padded knock',
    'seconds': .26,
  },
  {
    'id': 'win',
    'title': 'Match won',
    'group': 'Results and rewards',
    'when': 'The match result is a win.',
    'a': 'Short lantern flourish',
    'b': 'Warm plucked cadence',
    'seconds': .80,
  },
  {
    'id': 'lose',
    'title': 'Match lost',
    'group': 'Results and rewards',
    'when': 'The match result is a loss.',
    'a': 'Gentle descending notes',
    'b': 'Quiet brush and knock',
    'seconds': .55,
  },
  {
    'id': 'purchase',
    'title': 'Purchase / reward',
    'group': 'Results and rewards',
    'when': 'A store purchase or daily-streak reward.',
    'a': 'Light coin tick',
    'b': 'Wooden token tap',
    'seconds': .28,
  },
  {
    'id': 'home-music',
    'title': 'Home / lobby music',
    'group': 'Music',
    'when':
        'Home and lobby. Current is the existing four-second offline ambience.',
    'a': 'Lantern strings',
    'b': 'Midnight plucks',
    'seconds': 12.0,
  },
  {
    'id': 'room-music',
    'title': 'Table-room music',
    'group': 'Music',
    'when':
        'While in the game room. Current offline mode shares the home ambience.',
    'a': 'Quiet strings',
    'b': 'Felt ambience',
    'seconds': 12.0,
  },
];

List<String> pathsFor(String id) => switch (id) {
  'slam' => [for (var i = 0; i < 3; i++) 'sfx/slam_$i.mp3'],
  'home-music' => ['music/bg_music.mp3'],
  'room-music' => ['music/room_music.mp3'],
  _ => ['sfx/$id.mp3'],
};

Uint8List wave(List<double> samples, int rate, double peak) {
  final largest = samples.fold<double>(0, (a, b) => math.max(a, b.abs()));
  final gain = largest == 0 ? 0.0 : peak / largest;
  final data = ByteData(44 + samples.length * 2);
  void label(int at, String value) {
    for (var i = 0; i < value.length; i++) {
      data.setUint8(at + i, value.codeUnitAt(i));
    }
  }

  label(0, 'RIFF');
  data.setUint32(4, data.lengthInBytes - 8, Endian.little);
  label(8, 'WAVE');
  label(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  label(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(
      44 + i * 2,
      (samples[i] * gain * 32767).round().clamp(-32767, 32767),
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}

double tone(double t, double f) => math.sin(2 * math.pi * f * t);
double note(double t, double start, double f, {double decay = 12}) {
  final age = t - start;
  if (age < 0) return 0;
  return (1 - math.exp(-age * 700)) *
      math.exp(-age * decay) *
      (tone(age, f) + .25 * tone(age, f * 2) + .08 * tone(age, f * 3));
}

double burst(double t, double at, double decay, double signal) =>
    t < at ? 0 : signal * math.exp(-(t - at) * decay);

Uint8List effect(String id, int variant, double seconds) {
  if (variant >= 2) return extraEffect(id, variant, seconds);
  const rate = 44100;
  final random = math.Random(
    1940 + events.indexWhere((e) => e['id'] == id) * 31 + variant,
  );
  var low = 0.0, paper = 0.0;
  final samples = <double>[];
  for (var i = 0; i < (seconds * rate).round(); i++) {
    final t = i / rate, n = random.nextDouble() * 2 - 1;
    low += .065 * (n - low);
    paper += .39 * (n - paper);
    final high = n - paper;
    double value;
    switch (id) {
      case 'pick':
        value =
            (variant == 0 ? paper * .6 : high * .35) *
            math.exp(-t * (variant == 0 ? 85 : 140));
      case 'return':
        value =
            (variant == 0 ? paper : high * .35) *
            math.sin(math.pi * t / seconds) *
            math.exp(-t * 14);
      case 'play':
        value =
            (high * .17 +
                    paper * .6 +
                    tone(t, variant == 0 ? 185 : 240) * .12) *
                math.exp(-t * (variant == 0 ? 65 : 80)) +
            (variant == 0 ? 0 : burst(t, .012, 125, paper * .4));
      case 'deal':
        value =
            (variant == 0 ? paper : high * .4) *
                math.sin(math.pi * t / seconds) *
                math.exp(-t * 10) +
            (variant == 0 ? 0 : burst(t, .07, 80, paper * .25));
      case 'reveal':
        value =
            paper * .3 * math.sin(math.pi * t / seconds) +
            burst(
              t,
              variant == 0 ? .14 : .18,
              90,
              low * .7 + tone(t, 175) * .025,
            );
      case 'slam':
        value =
            high * math.exp(-t * 900) * .6 +
            paper * math.exp(-math.pow((t - .007) / .004, 2)) * 1.6 +
            (n - low) *
                math.exp(-t * (variant == 0 ? 105 : 70)) *
                (.12 + .08 * tone(t, 75)) +
            (low * 1.6 + tone(t, variant == 0 ? 185 : 150) * .15) *
                math.exp(-t * (variant == 0 ? 75 : 48));
      case 'capture':
        value =
            paper * .45 * math.sin(math.pi * t / seconds) +
            (variant == 0
                ? burst(t, .22, 60, low * .5)
                : .065 * (note(t, .12, 523.25) + note(t, .20, 659.25)));
      case 'shuffle':
        value = 0;
        for (var packet = 0; packet < (variant == 0 ? 11 : 5); packet++) {
          final at = .015 + packet * (variant == 0 ? .032 : .088);
          value += burst(
            t,
            at,
            variant == 0 ? 220 : 100,
            paper * .9 + high * .12,
          );
        }
      case 'cut':
        value =
            burst(t, .018, 70, low + tone(t, 180) * .06) +
            (variant == 0
                ? burst(t, .14, 65, paper * .45 + tone(t, 145) * .04)
                : 0);
      case 'win':
        final f = variant == 0
            ? [523.25, 659.25, 783.99, 1046.5]
            : [293.66, 369.99, 440.0, 587.33];
        value = 0;
        for (var k = 0; k < f.length; k++) {
          value +=
              note(t, .02 + k * .13, f[k], decay: variant == 0 ? 13 : 8) * .16;
        }
      case 'lose':
        value = variant == 0
            ? .15 *
                  (note(t, .01, 349.23, decay: 11) +
                      note(t, .18, 293.66, decay: 11))
            : paper * .2 * math.sin(math.pi * t / seconds) * math.exp(-t * 6) +
                  burst(t, .09, 65, low * .5);
      case 'purchase':
        value = variant == 0
            ? .11 * note(t, .003, 1567.98, decay: 32) +
                  .05 * note(t, .026, 2093, decay: 34)
            : (paper * .35 + tone(t, 420) * .08) * math.exp(-t * 60) +
                  burst(t, .06, 100, low * .3);
      default:
        throw StateError('Missing sound $id');
    }
    final edge = math.min(1.0, t / .002) * math.min(1.0, (seconds - t) / .025);
    samples.add(value * edge);
  }
  // A softer slam is intentionally quieter than the firmer alternative.
  return wave(samples, rate, id == 'slam' ? (variant == 0 ? .55 : .78) : .62);
}

// C, D and E change rhythm, material and envelope, not merely playback gain.
Uint8List extraEffect(String id, int variant, double seconds) {
  const rate = 44100;
  final warm = variant == 2, bright = variant == 3;
  final random = math.Random(
    8721 + events.indexWhere((e) => e['id'] == id) * 47 + variant,
  );
  var low = 0.0, paper = 0.0;
  final samples = <double>[];
  for (var i = 0; i < (seconds * rate).round(); i++) {
    final t = i / rate, noise = random.nextDouble() * 2 - 1;
    low += .035 * (noise - low);
    paper += .24 * (noise - paper);
    final crisp = noise - paper;
    final grain = warm
        ? paper
        : bright
        ? crisp * .45 + paper * .15
        : low;
    double tap(double at, double frequency, double decay) =>
        burst(t, at, decay, grain * .65 + low * .8) +
        note(t, at, frequency, decay: decay) * (bright ? .018 : .065);
    final slide =
        grain *
        math.sin(math.pi * t / seconds) *
        math.exp(-t * (bright ? 22 : 8));
    double value;
    switch (id) {
      case 'pick':
        value =
            grain *
                math.exp(
                  -t *
                      (warm
                          ? 70
                          : bright
                          ? 190
                          : 95),
                ) +
            (warm ? note(t, .003, 290, decay: 100) * .025 : 0);
      case 'return':
        value = bright
            ? burst(t, .014, 100, crisp * .25) + tap(.065, 260, 100)
            : slide * (warm ? .7 : .5);
      case 'play':
        value =
            tap(
              .006,
              warm
                  ? 145
                  : bright
                  ? 390
                  : 105,
              warm
                  ? 50
                  : bright
                  ? 135
                  : 72,
            ) +
            (bright ? tap(.025, 530, 155) * .55 : 0);
      case 'deal':
        value = bright
            ? burst(t, .008, 90, crisp * .4) + burst(t, .035, 135, paper * .5)
            : slide * .65 + (warm ? tap(.105, 220, 95) * .18 : 0);
      case 'reveal':
        value =
            slide * .5 +
            tap(
                  bright ? .13 : .17,
                  warm
                      ? 210
                      : bright
                      ? 420
                      : 110,
                  85,
                ) *
                (warm
                    ? .5
                    : bright
                    ? .35
                    : .12);
      case 'slam':
        value =
            tap(
              .004,
              warm
                  ? 125
                  : bright
                  ? 310
                  : 95,
              warm
                  ? 38
                  : bright
                  ? 100
                  : 55,
            ) +
            burst(t, .006, bright ? 360 : 180, crisp * (bright ? .65 : .25)) +
            burst(
              t,
              bright ? .026 : .012,
              bright ? 150 : 80,
              paper * (bright ? .8 : .4),
            );
      case 'capture':
        value = slide * .55;
        if (bright) {
          for (var k = 0; k < 3; k++) {
            value +=
                note(t, .04 + k * .07, [659.25, 783.99, 987.77][k], decay: 23) *
                .07;
          }
        } else {
          value += tap(warm ? .21 : .25, warm ? 155 : 110, 65) * .4;
        }
      case 'shuffle':
        value = 0;
        if (!warm && !bright) {
          value =
              paper *
              .25 *
              math.pow(math.sin(math.pi * t / seconds), 2) *
              (.55 + .2 * tone(t, 17) + .15 * tone(t, 29));
        } else {
          final packets = warm ? 6 : 18;
          for (var k = 0; k < packets; k++) {
            final at = warm
                ? .018 + k * .064 + (k.isOdd ? .011 : 0)
                : .02 + k * .021;
            value += burst(t, at, warm ? 95 : 260, grain * .7 + paper * .18);
          }
        }
      case 'cut':
        value = tap(
          .015,
          warm
              ? 150
              : bright
              ? 360
              : 95,
          warm
              ? 55
              : bright
              ? 110
              : 65,
        );
        if (warm || bright) value += tap(.115, warm ? 190 : 480, 90) * .7;
        if (bright) value += tap(.155, 290, 130) * .4;
      case 'win':
        value = 0;
        final frequencies = warm
            ? [293.66, 311.13, 440.0, 587.33]
            : bright
            ? [783.99, 987.77, 1174.66, 1567.98]
            : [261.63, 329.63, 392.0];
        for (var k = 0; k < frequencies.length; k++) {
          value +=
              note(
                t,
                bright
                    ? .01 + k * .10
                    : warm
                    ? .02 + k * .14
                    : .02 + k * .025,
                frequencies[k],
                decay: bright
                    ? 16
                    : warm
                    ? 9
                    : 7,
              ) *
              .12;
        }
      case 'lose':
        value = warm
            ? .14 *
                  (note(t, .015, 220, decay: 10) + note(t, .16, 196, decay: 9))
            : bright
            ? .1 *
                  (note(t, .01, 783.99, decay: 18) +
                      note(t, .12, 659.25, decay: 18) +
                      note(t, .24, 523.25, decay: 18))
            : .12 * note(t, .025, 174.61, decay: 9);
      case 'purchase':
        value = warm
            ? tap(.008, 610, 80) + tap(.065, 455, 100) * .65
            : bright
            ? .10 * note(t, .003, 1760, decay: 30) +
                  .08 * note(t, .048, 2637.02, decay: 34) +
                  .05 * note(t, .086, 3135.96, decay: 45)
            : .08 * note(t, .008, 440, decay: 28) +
                  low * math.exp(-t * 75) * .2;
      default:
        throw StateError('Missing extra sound $id');
    }
    final fade = math.min(1.0, t / .002) * math.min(1.0, (seconds - t) / .025);
    samples.add(value * fade);
  }
  return wave(
    samples,
    rate,
    variant == 4
        ? .36
        : id == 'slam'
        ? (bright ? .78 : .70)
        : .62,
  );
}

Uint8List music(String id, int variant) {
  if (variant >= 2) return extraMusic(id, variant);
  const seconds = 12.0, rate = 22050;
  final room = id == 'room-music';
  final samples = <double>[];
  final melody = variant == 0
      ? [293.66, 311.13, 369.99, 392.0, 440.0, 392.0, 369.99, 293.66]
      : [293.66, 349.23, 392.0, 440.0, 523.25, 440.0, 392.0, 349.23];
  for (var i = 0; i < (rate * seconds).round(); i++) {
    final t = i / rate;
    double periodic(double f) => tone(t, (f * seconds).round() / seconds);
    var value =
        .07 * (periodic(146.83) + .35 * periodic(220) + .15 * periodic(293.66));
    if (!(room && variant == 1)) {
      for (var k = 0; k < melody.length; k++) {
        final age = (t - k * 1.5 + seconds) % seconds;
        if (age > 2.8) continue;
        final f = (melody[k] * seconds).round() / seconds;
        final pluck =
            (tone(age, f) +
                .38 * tone(age, f * 2) +
                .12 * tone(age, f * 3) +
                .04 * tone(age, f * 5)) *
            (1 - math.exp(-age * 500)) *
            math.exp(-age * (room ? 3.6 : 2.8));
        value += pluck * (room ? .10 : .19);
      }
    } else {
      value += .04 * periodic(349.23) * (.7 + .3 * tone(t, 1 / seconds));
    }
    if (!room && variant == 1) {
      final age = t % 1.5;
      value += tone(age, 80) * math.exp(-age * 55) * .022;
    }
    samples.add(value);
  }
  return wave(samples, rate, room ? .20 : .28);
}

Uint8List extraMusic(String id, int variant) {
  const seconds = 12.0, rate = 22050;
  final room = id == 'room-music', modal = variant == 2, pulse = variant == 3;
  final melody = modal
      ? [220.0, 233.08, 293.66, 329.63, 293.66, 233.08]
      : [196.0, 246.94, 293.66, 392.0, 329.63, 293.66, 246.94, 220.0];
  final samples = <double>[];
  for (var i = 0; i < (seconds * rate).round(); i++) {
    final t = i / rate;
    double periodic(double f) => tone(t, (f * seconds).round() / seconds);
    var value =
        (modal
            ? .03
            : pulse
            ? .02
            : .045) *
        (periodic(
              modal
                  ? 110
                  : pulse
                  ? 98
                  : 130.81,
            ) +
            .4 *
                periodic(
                  modal
                      ? 164.81
                      : pulse
                      ? 146.83
                      : 196,
                ));
    if (modal || pulse) {
      final spacing = seconds / melody.length;
      for (var k = 0; k < melody.length; k++) {
        final age = (t - k * spacing + seconds) % seconds;
        final f = (melody[k] * (room ? .5 : 1) * seconds).round() / seconds;
        value +=
            (tone(age, f) +
                (modal ? .16 : .42) * tone(age, f * 2) +
                (modal ? .08 : .12) * tone(age, f * 4)) *
            (1 - math.exp(-age * 250)) *
            math.exp(-age * (modal ? 2.4 : 4.5)) *
            (room ? .08 : .15);
      }
    } else {
      // Entirely periodic slow pad: deliberately no melody or percussion.
      value +=
          .025 * periodic(261.63) * (.7 + .3 * tone(t, 1 / seconds)) +
          .012 * periodic(293.66) * (.7 + .3 * tone(t, 2 / seconds));
    }
    if (pulse) {
      final age = t % .75;
      value +=
          tone(age, 72) *
          (1 - math.exp(-age * 500)) *
          math.exp(-age * 65) *
          (room ? .010 : .022);
    }
    samples.add(value);
  }
  return wave(
    samples,
    rate,
    variant == 4
        ? (room ? .12 : .18)
        : room
        ? .20
        : .28,
  );
}

Map<String, Object> metrics(Uint8List bytes) {
  final data = ByteData.sublistView(bytes), count = (bytes.length - 44) ~/ 2;
  final rate = data.getUint32(24, Endian.little);
  var energy = 0.0, peak = 0.0, tail = 0.0, hash = 2166136261;
  for (final byte in bytes) {
    hash = ((hash ^ byte) * 16777619) & 0xffffffff;
  }
  for (var i = 0; i < count; i++) {
    final sample = data.getInt16(44 + i * 2, Endian.little) / 32768;
    energy += sample * sample;
    peak = math.max(peak, sample.abs());
    if (i > count - rate * .01) tail += sample * sample;
  }
  if (energy <= 0 || !energy.isFinite || peak >= 1) {
    throw StateError('Invalid audio');
  }
  return {
    'seconds': count / rate,
    'sampleRate': rate,
    'bytes': bytes.length,
    'peak': peak,
    'rms': math.sqrt(energy / count),
    'tailRms': math.sqrt(tail / math.min(count, rate * .01)),
    'fnv1a32': hash,
  };
}

Future<void> main() async {
  if (!const bool.fromEnvironment('HALABESSA_CARD_UI_REFINEMENTS')) {
    throw StateError(
      'Run with -DHALABESSA_CARD_UI_REFINEMENTS=true to preserve the approved slam A.',
    );
  }
  final output = Directory(reviewDirectory);
  await Directory('${output.path}/audio').create(recursive: true);
  final catalog = <Map<String, Object>>[];
  for (final event in events) {
    final id = event['id']! as String, isMusic = id.endsWith('-music');
    final current = isMusic
        ? DefaultAudioAssets.getMusic()
        : DefaultAudioAssets.getSfx(pathsFor(id).first)!;
    final candidates = <Map<String, Object>>[];
    for (var choice = 0; choice < 6; choice++) {
      final code = ['current', 'a', 'b', 'c', 'd', 'e'][choice];
      final file = 'audio/$id-$code.wav';
      final target = File('${output.path}/$file');
      // Auditioned files are immutable: adding choices must not change old ones.
      final bytes = await target.exists()
          ? await target.readAsBytes()
          : choice == 0
          ? base64Decode(current.split(',').last)
          : isMusic
          ? music(id, choice - 1)
          : effect(id, choice - 1, event['seconds']! as double);
      if (!await target.exists()) await target.writeAsBytes(bytes);
      candidates.add({
        'id': code,
        'file': file,
        'label': choice == 0
            ? (id == 'slam'
                  ? 'Current — approved slam A'
                  : 'Current bundled sound')
            : choice < 3
            ? event[code]!
            : extraChoices[id]![choice - 3],
        ...metrics(bytes),
      });
    }
    catalog.add({
      ...event,
      'assetPaths': pathsFor(id),
      'candidates': candidates,
      if (id == 'slam') 'approvedChoice': 'current',
    });
  }
  await File('${output.path}/catalog.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'schema': 1,
      'date': '2026-10-24',
      'reviewOnly': true,
      'description':
          'Procedural local candidates, not recorded Foley or real-instrument recordings. No defaults applied.',
      'events': catalog,
    }),
  );
  for (final name in ['index.html', 'app.js', 'styles.css']) {
    await File('tool/sound_review/$name').copy('${output.path}/$name');
  }
  stdout.writeln(
    'Generated ${catalog.length} event groups, ${catalog.length * 6} WAV clips; existing clips preserved; no game settings changed.',
  );
}
