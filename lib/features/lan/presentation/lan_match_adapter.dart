import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/multimedia_service.dart';
import '../../auth/domain/models/app_user.dart';
import '../../game/domain/models/match_state.dart';
import '../../game/domain/models/bot_difficulty.dart';
import '../../game/domain/models/card.dart' as game;
import '../../game/domain/providers/game_providers.dart';
import '../../game/presentation/pages/offline_practice_app.dart';
import '../domain/lan_protocol.dart';
import '../data/lan_connection.dart';

/// Full state exists exclusively here on the host. The rendered host hand uses
/// the same private snapshot path as the other participants.
class LanMatchDriver implements LanGameDriver {
  LanMatchDriver(this.preferences, this.profile);
  final SharedPreferences preferences;
  final AppUser profile;
  ProviderContainer? _container;
  ProviderSubscription<MatchState?>? _subscription;
  Timer? _tick;
  final _changes = StreamController<MatchState>.broadcast(sync: true);
  @override
  Stream<MatchState> get changes => _changes.stream;
  @override
  MatchState? get state => _container?.read(matchStateProvider);

  @override
  Future<void> start(
    String room,
    List<LanMember> humans, {
    required String mode,
  }) async {
    if (_container != null || humans.isEmpty || humans.length > 4) {
      throw StateError('lan_cannot_start');
    }
    final player = profile.copyWith(uid: humans.first.uid);
    final container = _container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        ...offlinePlayOverrides(
          preferences,
          player,
          audioFactory: (_) => _SilentAuthority(),
        ),
      ],
    );
    _subscription = container.listen(matchStateProvider, (_, next) {
      if (next != null && !_changes.isClosed) _changes.add(next);
    });
    final ids = [
      for (final human in humans) human.uid,
      for (var i = humans.length; i < 4; i++) 'bot_${i + 1}',
    ];
    container
        .read(matchStateProvider.notifier)
        .startLocalNetworkMatch(
          MatchState(
            id: 'OFFLINE_LAN_$room',
            dealerIndex: 0,
            currentTurnIndex: 1,
            mode: GameMode.values.byName(mode),
            playerIds: ids,
            isPublic: false,
            playerNames: {
              for (final human in humans) human.uid: human.name,
              for (final id in ids.where((id) => id.startsWith('bot_')))
                id: 'bot_name_template',
            },
            playerAvatars: {for (final id in ids) id: ''},
            playerOnlineStatus: {for (final id in ids) id: true},
            botDifficulties: {
              for (final id in ids.where((id) => id.startsWith('bot_')))
                id: BotDifficulty.medium.name,
            },
            playerSkins: {for (final id in ids) id: 'default_card'},
            timerDurationSeconds: 12,
          ),
        );
    _tick = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => container.read(matchStateProvider.notifier).tickLocalNetworkHost(),
    );
  }

  @override
  Future<bool> command(
    String uid,
    String action,
    Map<String, dynamic> payload,
  ) async {
    final current = state;
    if (current == null ||
        !current.playerIds.contains(uid) ||
        uid.startsWith('bot_')) {
      return false;
    }
    final notifier = _container!.read(matchStateProvider.notifier);
    switch (action) {
      case 'play':
      case 'show':
        final raw = payload['card'];
        if (raw is! Map ||
            raw.length != 2 ||
            !game.Suit.values.any((s) => s.name == raw['suit']) ||
            !game.Rank.values.any((r) => r.name == raw['rank'])) {
          return false;
        }
        final card = game.Card.fromJson(Map<String, dynamic>.from(raw));
        if (!(current.handCards[uid]?.contains(card) ?? false)) return false;
        if (action == 'show') return notifier.showCard(uid, card);
        if (payload['slam'] != null && payload['slam'] is! bool) return false;
        return notifier.playCard(
          uid,
          card,
          gestureSlam: payload['slam'] == true,
        );
      case 'cut':
        final position = payload['position'];
        if (current.phase != GamePhase.preRoundCut ||
            current.playerIds[current.dealerIndex] != uid ||
            position is! int ||
            position < 1 ||
            position >= current.deckCount) {
          return false;
        }
        await notifier.performCut(position);
        return true;
      case 'voteShuffle':
        if (payload['vote'] is! bool ||
            current.phase != GamePhase.shuffleVoting) {
          return false;
        }
        return notifier.voteShuffle(uid, payload['vote'] as bool);
      case 'voteRematch':
        if (payload['vote'] is! bool ||
            current.phase != GamePhase.rematchVoting) {
          return false;
        }
        return notifier.voteRematch(uid, payload['vote'] as bool);
      case 'emoji':
        final emoji = payload['emoji'];
        if (emoji is! String ||
            emoji.runes.isEmpty ||
            emoji.runes.length > 8 ||
            RegExp(r'[\x00-\x1f]').hasMatch(emoji)) {
          return false;
        }
        await notifier.sendEmoji(uid, emoji);
        return true;
      default:
        return false;
    }
  }

  @override
  Future<void> presence(String uid, bool connected) async {
    final container = _container;
    if (container != null) {
      await container
          .read(matchStateProvider.notifier)
          .setLocalNetworkPresence(uid, connected);
    }
  }

  @override
  Future<void> close() async {
    _tick?.cancel();
    _subscription?.close();
    _container?.dispose();
    _container = null;
    if (!_changes.isClosed) await _changes.close();
  }
}

class _SilentAuthority extends ChangeNotifier implements MultimediaService {
  @override
  Future<void> playSfx(String assetPath) async {}
  @override
  Future<void> vibrate() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('lan_authority_has_no_presentation');
}

class LanReplicaNotifier extends MatchStateNotifier {
  LanReplicaNotifier(super.ref, this.connection) {
    connection.addListener(_adopt);
    _adopt();
  }
  final LanConnection connection;
  int _revision = -1;
  bool _resync = false;
  void _adopt() {
    if (connection.status != 'connected') {
      _resync = true;
      return;
    }
    final view = connection.snapshot;
    if (!mounted ||
        view == null ||
        view['match'] is! Map ||
        (view['revision'] as int) <= _revision) {
      return;
    }
    _revision = view['revision'] as int;
    final previous = state;
    state = lanDisplaySnapshot(
      Map<String, dynamic>.from(view['match'] as Map),
      view['hostNow'] as int,
      DateTime.fromMillisecondsSinceEpoch(
        (view['hostNow'] as int) + connection.clockOffsetMs,
      ),
    ).copyWith(serverVersion: _revision);
    // This labels the private viewer projection only. Commands still use the
    // connection's host revision; the host's engine state is never rewritten.
    lastBoundMatchId = state!.id;
    if (previous != null && !_resync) _fallbackAudio(previous, state!);
    _resync = false;
  }

  // Same cues the local engine emits, played on each viewer. Presentation
  // leases in MultimediaService suppress these when the animated layer owns it.
  void _fallbackAudio(MatchState before, MatchState after) {
    String? sound;
    if (after.roundCount != before.roundCount &&
        after.roundsSinceLastShuffle == 0) {
      sound = 'shuffle';
    } else if (before.phase == GamePhase.preRoundCut &&
        after.phase == GamePhase.dealingFasha) {
      sound = 'cut';
    } else if (after.handInRound > before.handInRound) {
      sound = 'deal';
    } else if (after.phase == GamePhase.capturing &&
        before.phase != GamePhase.capturing) {
      sound = 'capture';
    } else if (after.phase == GamePhase.playing &&
        before.phase == GamePhase.playing &&
        after.board.length == before.board.length + 1) {
      sound = 'play';
    }
    if (sound != null) {
      unawaited(ref.read(multimediaServiceProvider).playSfx('sfx/$sound.mp3'));
    }
  }

  Future<bool> _send(String action, Map<String, dynamic> payload) async {
    final accepted = await connection.command(action, payload);
    if (!accepted && mounted) {
      ref.read(matchFeedbackProvider.notifier).state = MatchFeedback(
        'match_action_retry',
      );
    }
    if (accepted && action == 'emoji' && mounted) {
      unawaited(ref.read(multimediaServiceProvider).vibrate());
    }
    return accepted;
  }

  @override
  Future<bool> playCard(
    String playerId,
    game.Card card, {
    Offset? origin,
    bool gestureSlam = false,
  }) async {
    if (playerId != connection.uid) return false;
    if (origin != null) {
      ref
          .read(localPlayOriginsProvider.notifier)
          .update((m) => {...m, card.firebaseKey: origin});
    }
    return _send('play', {'card': card.toJson(), 'slam': gestureSlam});
  }

  @override
  Future<bool> showCard(String playerId, game.Card card) async =>
      playerId == connection.uid &&
      await _send('show', {'card': card.toJson()});
  @override
  Future<void> performCut(int index) async {
    await _send('cut', {'position': index});
  }

  @override
  Future<bool> voteShuffle(
    String playerId,
    bool wantsShuffle, {
    MatchState? expected,
  }) async =>
      playerId == connection.uid &&
      await _send('voteShuffle', {'vote': wantsShuffle});
  @override
  Future<bool> voteRematch(
    String playerId,
    bool wantsRematch, {
    MatchState? expected,
  }) async =>
      playerId == connection.uid &&
      await _send('voteRematch', {'vote': wantsRematch});
  @override
  Future<void> sendEmoji(String playerId, String emoji) async {
    if (playerId == connection.uid) await _send('emoji', {'emoji': emoji});
  }

  // Peer renderers never deal, run bots, vote for other seats or start rounds.
  @override
  Future<void> startNewRound({
    bool isFirstRound = false,
    bool forceShuffle = false,
  }) async {}
  @override
  Future<void> dealInitialCards() async {}
  @override
  Future<void> dealSubsequentCards() async {}
  @override
  Future<void> voteForBots(String playerId) async {}
  @override
  Future<void> clearEmoji(String playerId) async {}
  @override
  void bindToMatch(String matchId, {bool spectating = false}) {}
  @override
  Future<MatchRecoveryStart> tryRecoverLastMatch() async =>
      MatchRecoveryStart.listening;
  @override
  Future<bool> leaveMatch({bool notifyServer = true}) async {
    if (notifyServer) await connection.close();
    return true;
  }

  @override
  void dispose() {
    connection.removeListener(_adopt);
    super.dispose();
  }
}
