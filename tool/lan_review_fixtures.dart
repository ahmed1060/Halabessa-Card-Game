// Local UI fixtures only. No sockets, NSD, camera, cloud accounts or writes.
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:halabessa/core/services/multimedia_service.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game;
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/lan/data/lan_connection.dart';
import 'package:halabessa/features/lan/data/lan_discovery.dart';
import 'package:halabessa/features/lan/domain/lan_protocol.dart';

class ReviewLanDiscovery extends LanDiscovery {
  int browsed = 0;
  @override
  List<nsd.Service> get rooms => [
    const nsd.Service(
      name: 'Halabessa Café',
      type: lanServiceType,
      host: '192.168.1.20',
      port: 16060,
    ),
  ];
  @override
  Future<void> browse() async {
    browsed++;
  }

  @override
  Future<void> advertise(int port, String name) async {}
  @override
  Future<void> stop() async {}
}

class ReviewLanConnection extends LanConnection {
  ReviewLanConnection({this.uid = 'LOCAL_LAN_review_host'}) {
    snapshot = {
      'v': 1,
      'type': 'snapshot',
      'room': room,
      'revision': 0,
      'hostNow': DateTime.now().millisecondsSinceEpoch,
      'started': false,
      'closed': false,
      'members': [
        {'uid': uid, 'name': 'Ahmed', 'connected': true},
        {'uid': 'LOCAL_LAN_review_other', 'name': 'Mona', 'connected': true},
      ],
    };
  }
  final String room = 'local_review_room_1234';
  @override
  final String uid;
  @override
  int get clockOffsetMs => 0;
  @override
  String status = 'connected';
  @override
  Map<String, dynamic>? snapshot;
  int closeCount = 0;
  void publish(Map<String, dynamic> next) {
    snapshot = {
      ...snapshot!,
      ...next,
      'revision': (snapshot!['revision'] as int) + 1,
      'hostNow': DateTime.now().millisecondsSinceEpoch,
    };
    notifyListeners();
  }

  void table() {
    final state = MatchState(
      id: 'OFFLINE_LAN_$room',
      mode: GameMode.classic,
      playerIds: [uid, 'bot_2', 'LOCAL_LAN_review_other', 'bot_4'],
      dealerIndex: 0,
      currentTurnIndex: 1,
      phase: GamePhase.playing,
      roundCount: 1,
      handInRound: 1,
      deckCount: 32,
      handCards: {
        uid: const [
          game.Card(game.Suit.clubs, game.Rank.six),
          game.Card(game.Suit.diamonds, game.Rank.nine),
          game.Card(game.Suit.clubs, game.Rank.ace),
          game.Card(game.Suit.spades, game.Rank.eight),
        ],
      },
      handCounts: {uid: 4, 'bot_2': 4, 'LOCAL_LAN_review_other': 4, 'bot_4': 4},
      playerNames: {
        uid: 'Ahmed',
        'bot_2': 'Bot 1',
        'LOCAL_LAN_review_other': 'Mona',
        'bot_4': 'Bot 3',
      },
      botDifficulties: const {'bot_2': 'medium', 'bot_4': 'medium'},
      board: const [game.Card(game.Suit.hearts, game.Rank.seven)],
      turnStartTime: DateTime.now(),
    );
    publish({
      'started': true,
      'match': {
        ...state.toJson(),
        'handCards': {
          uid: state.handCards[uid]!.map((c) => c.toJson()).toList(),
        },
      },
    });
  }

  @override
  Future<bool> command(String action, Map<String, dynamic> payload) async =>
      false;
  @override
  Future<void> reconnect() async {
    status = 'connected';
    notifyListeners();
  }

  @override
  Future<void> close({bool leave = true}) async {
    if (status == 'ended') return;
    closeCount++;
    status = 'ended';
    publish({'closed': true, 'reason': 'lan_host_ended'});
  }
}

class ReviewLanHost implements LanHostedRoom {
  ReviewLanHost({this.driver});
  final LanGameDriver? driver;
  @override
  final ReviewLanConnection local = ReviewLanConnection();
  @override
  List<String> get addresses => ['192.168.1.20'];
  @override
  int get port => 16060;
  @override
  String get room => local.room;
  @override
  LanInvitation invitation(String address) => LanInvitation(
    address: address,
    port: port,
    room: room,
    fingerprint: '1' * 64,
    secret: 'A' * 43,
  );
  @override
  Future<void> start({String mode = 'classic'}) async => local.table();
  @override
  Future<void> close() async {
    await local.close();
    await driver?.close();
  }
}

class ReviewLanAudio extends ChangeNotifier implements MultimediaService {
  @override
  Future<void> playMusic(String assetPath, {bool loop = true}) async {}
  @override
  Future<void> playRoomMusic(String assetPath, {bool loop = true}) async {}
  @override
  Future<void> playSfx(String assetPath) async {}
  @override
  Future<void> playPresentationSfx(String assetPath) async {}
  @override
  Future<void> stopMusic() async {}
  @override
  Future<void> stopSfx() async {}
  @override
  Future<void> vibrate() async {}
  @override
  void handleInteraction() {}
  @override
  void Function() ownDeckPresentationAudio(Object owner) => () {};
  @override
  void Function() ownCardPresentationAudio(Object owner) => () {};
  @override
  PlayerState get musicState => PlayerState.stopped;
  @override
  PlayerState get sfxState => PlayerState.stopped;
  @override
  String? get currentMusicPath => null;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected review audio operation');
}
