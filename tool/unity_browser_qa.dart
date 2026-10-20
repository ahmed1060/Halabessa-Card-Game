// Separate local fixture entry point. No Firebase, accounts, rooms or commands.
import 'dart:async';
import 'dart:convert';
// QA-only inspection of the already-created canvas context.
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:halabessa/core/utils/web_registry.dart';
import 'package:halabessa/core/utils/web_utils.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/game/presentation/providers/unity_visual_presentation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerWebUnityView();
  runApp(const MaterialApp(home: BrowserQa()));
}

class BrowserQa extends StatefulWidget {
  const BrowserQa({super.key});
  @override
  State<BrowserQa> createState() => _BrowserQaState();
}

class _BrowserQaState extends State<BrowserQa> {
  late final UnityVisualPresentation visual;
  StreamSubscription<dynamic>? messages;
  final checks = <String>[], contacts = <String>[], received = <String>[];
  final inputIntents = <String>[];
  final waiting = <String, Completer<void>>{};
  final sentAt = <String, DateTime>{};
  final elapsed = <String, int>{};
  int version = 0;
  bool running = false;
  bool? canvasAlpha;
  int? backgroundAlpha;
  String status = 'Waiting for real WebGL handshake';
  Map<String, String> card(String rank, String suit) => {
    'rank': rank,
    'suit': suit,
  };
  MatchState fixture({bool played = false, bool captured = false}) =>
      MatchState.fromJson({
        'id': 'LOCAL_VISUAL_QA',
        'protocolVersion': 1,
        'serverVersion': ++version,
        'playerIds': ['local', 'opponent', 'partner', 'other'],
        'phase': 'playing',
        'roundCount': 1,
        'handCards': {
          'local': [
            card('ace', 'clubs'),
            card('eight', 'spades'),
            if (!played) card('king', 'diamonds'),
            if (!captured) card('six', 'hearts'),
          ],
          'opponent': [card('queen', 'hearts')],
        },
        'board': [
          if (!captured) card('six', 'clubs'),
          card('nine', 'hearts'),
          if (played) card('king', 'diamonds'),
        ],
        'cardOwnership': {'diamonds_king': 'local'},
        'captureEvents': captured
            ? [
                {
                  'id': 'capture-$version',
                  'team': 'teamA',
                  'playerUid': 'local',
                  'createdAt': DateTime.now().toIso8601String(),
                  'cards': [card('six', 'clubs'), card('six', 'hearts')],
                },
              ]
            : [],
      });

  @override
  void initState() {
    super.initState();
    visual = UnityVisualPresentation(
      send: (message) {
        if (message['type'] == 'VISUAL_ACTION') {
          final id = message['eventId'] as String;
          waiting[id] = Completer<void>();
          sentAt[id] = DateTime.now();
          check(
            !message.containsKey('playerHands') &&
                (message['handCards'] as List).every(
                  (card) =>
                      !(card['rank'] == 'queen' && card['suit'] == 'hearts'),
                ),
            'no opponent private face transmitted',
          );
        }
        WebUtils.postMessage(
          jsonEncode({
            'objectName': 'UnityBridge',
            'methodName': 'OnFlutterMessage',
            'message': jsonEncode(message),
          }),
          WebUtils.window.location.origin,
        );
      },
      onContact: (id, _) {
        contacts.add(id);
      },
    );
    visual.updateAnchors([
      {'name': 'hand', 'x': .65, 'y': .88},
      {'name': 'board', 'x': .5, 'y': .53},
      {'name': 'deck', 'x': .3, 'y': .18},
      {'name': 'ownPile', 'x': .12, 'y': .85},
      {'name': 'opponentPile', 'x': .9, 'y': .24},
    ]);
    visual.accept(fixture(), 'local', active: true, reduced: false);
    messages = WebUtils.onMessage?.listen((event) {
      if (event.origin != WebUtils.window.location.origin ||
          event.source != WebUtils.window ||
          event.data is! String) {
        return;
      }
      try {
        final data = jsonDecode(event.data as String);
        if (data is! Map || data['event'] == null) return;
        received.add(data['event'] as String);
        if (data['event'] == 'UNITY_VISUAL_READY') {
          setWebUnityPointerEvents(
            true,
          ); // Isolated input intents, no game commands.
          visual.negotiate(data['data'] == '1' ? 1 : 0);
          status = 'Real WebGL protocol ${data['data']} ready';
          check(visual.capable, 'protocol handshake');
          Timer(const Duration(seconds: 3), () {
            if (!mounted) return;
            readCanvasAlpha();
            setState(() {});
          });
        } else if (data['event'] == 'VISUAL_CONTACT') {
          visual.contact(data['eventId'] as String, data['generation'] as int);
        } else if (data['event'] == 'VISUAL_ACTION_COMPLETE') {
          final id = data['eventId'] as String;
          if (visual.acknowledge(id, data['generation'] as int)) {
            elapsed[id] = DateTime.now().difference(sentAt[id]!).inMilliseconds;
            waiting[id]?.complete();
          }
        } else if (data['event'] == 'UNITY_FAILED') {
          status = 'FAIL: Unity startup';
        } else if (data['event'] == 'PLAY_CARD') {
          inputIntents.add(data['data'] as String);
        }
        if (mounted) setState(() {});
      } catch (error) {
        status = 'FAIL: $error';
        if (mounted) setState(() {});
      }
    });
  }

  void check(bool condition, String label) {
    if (!condition) throw StateError(label);
    checks.add(label);
  }

  void readCanvasAlpha() {
    final canvas = js.JsObject.fromBrowserObject(
      WebUtils.document.getElementById('unity-canvas')!,
    );
    final context = js.JsObject.fromBrowserObject(
      canvas.callMethod('getContext', ['webgl2']),
    );
    canvasAlpha = context.callMethod('getContextAttributes')['alpha'] as bool;
    final pixel = js.JsObject(js.context['Uint8Array'], [4]);
    context.callMethod('readPixels', [
      0,
      0,
      1,
      1,
      context['RGBA'],
      context['UNSIGNED_BYTE'],
      pixel,
    ]);
    backgroundAlpha = pixel[3] as int;
  }

  Future<void> finishLast() async {
    final id = waiting.keys.last;
    await waiting[id]!.future.timeout(const Duration(seconds: 4));
    check(
      contacts.where((value) => value == id).length == 1,
      'one real contact: ${id.split(':').last}',
    );
    check(visual.capable, 'no watchdog fallback');
  }

  Future<void> run() async {
    if (!visual.capable || running) return;
    setState(() {
      running = true;
      status = 'Running fixed local fixtures';
    });
    try {
      checks.clear();
      readCanvasAlpha(); // Measure the finished scene, not the startup splash.
      check(canvasAlpha == true, 'WebGL context supports alpha');
      check(backgroundAlpha == 0, 'empty playfield pixels remain transparent');
      contacts.clear();
      waiting.clear();
      sentAt.clear();
      elapsed.clear();
      visual.accept(fixture(), 'local', active: true, reduced: false);
      visual.resync();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      visual.accept(
        fixture(played: true),
        'local',
        active: true,
        reduced: false,
      );
      await finishLast();
      visual.accept(
        fixture(played: true, captured: true),
        'local',
        active: true,
        reduced: false,
      );
      await finishLast();
      final generation = visual.generation;
      check(
        visual.reject('clubs_ace', generation),
        'private-hand invalid return',
      );
      check(
        !visual.reject('hearts_queen', generation),
        'opponent invalid return rejected',
      );
      check(!visual.acknowledge('stale', generation - 1), 'stale ACK rejected');
      visual.accept(fixture(), 'local', active: true, reduced: true);
      visual.accept(
        fixture(played: true),
        'local',
        active: true,
        reduced: true,
      );
      await finishLast();
      visual.resync();
      status = 'PASS: ${checks.length} browser integration checks';
    } catch (error) {
      status = 'FAIL: $error';
    }
    if (mounted) {
      setState(() {
        running = false;
      });
    }
  }

  @override
  void dispose() {
    setWebUnityPointerEvents(false);
    messages?.cancel();
    visual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff3b274c),
    appBar: AppBar(
      title: const Text('Local Flutter + Unity QA — no live account'),
    ),
    body: Column(
      children: [
        Text(status, style: const TextStyle(color: Colors.white)),
        ElevatedButton(
          onPressed: visual.capable && !running ? run : null,
          child: const Text('Run browser checks'),
        ),
        const Expanded(child: HtmlElementView(viewType: 'unity-web-view')),
        SizedBox(
          height: 170,
          child: SingleChildScrollView(
            child: SelectableText(
              jsonEncode({
                'status': status,
                'canvasAlpha': canvasAlpha,
                'backgroundAlpha': backgroundAlpha,
                'inputIntents': inputIntents,
                'checks': checks,
                'elapsedMs': elapsed,
                'events': received,
              }),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}
