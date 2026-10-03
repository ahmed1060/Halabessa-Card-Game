import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/game/domain/models/card.dart' as game_card;
import 'package:halabessa/features/game/presentation/widgets/card_widget.dart';
import 'package:halabessa/features/game/presentation/widgets/fanned_hand_widget.dart';
import 'package:halabessa/features/game/domain/models/capture.dart';
import 'package:halabessa/features/home/presentation/providers/store_provider.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/core/widgets/settings_overlay.dart';
import 'package:halabessa/core/providers/settings_provider.dart';
import 'package:halabessa/features/game/presentation/providers/chat_providers.dart';
import 'package:halabessa/features/game/presentation/widgets/chat_overlay.dart';
import 'package:confetti/confetti.dart';
import '../widgets/player_profile_preview.dart';
import '../widgets/board_cards_widget.dart';
import '../widgets/match_table_layout.dart';
import '../widgets/table_seat.dart';
import '../widgets/table_style.dart';
import '../widgets/lantern_controls.dart';
import '../widgets/table_motion_geometry.dart';
import '../widgets/dealer_seat.dart';
import '../widgets/team_capture_stack.dart';
import '../widgets/match_phase_panel.dart';
import '../widgets/match_choice_panel.dart';
import '../widgets/match_result_view.dart';
import '../widgets/match_waiting_room_panel.dart';
import '../widgets/match_recovery_view.dart';
import '../widgets/basra_celebration_overlay.dart';
import '../widgets/emote_wheel_overlay.dart';
import 'package:flutter/services.dart';
import 'package:halabessa/core/services/multimedia_service.dart';
import 'package:halabessa/core/utils/error_handler.dart';
import 'package:halabessa/core/routes/app_routes.dart';
import '../providers/unity_communication_service.dart';
import '../providers/unity_layer_provider.dart';

class GameBoardScreen extends ConsumerStatefulWidget {
  const GameBoardScreen({super.key});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen> {
  late ConfettiController _confettiController;
  final GlobalKey _boardKey = GlobalKey();
  final GlobalKey _dealerDeckKey = GlobalKey();
  final GlobalKey _ourPileKey = GlobalKey();
  final GlobalKey _rivalPileKey = GlobalKey();
  final List<GlobalKey> _seatKeys = List.generate(4, (_) => GlobalKey());
  bool _isEmoteWheelOpen = false;

  void _returnToHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.initial, (_) => false);
  }

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    ref.read(localPlayOriginsProvider.notifier).state = {};
    
    final multimedia = ref.read(multimediaServiceProvider);
    final unityVisibility = ref.read(unityLayerVisibilityProvider.notifier);
    _restoreLobbyPresentation = () {
      if (!unityVisibility.mounted) return;
      multimedia.playMusic('music/bg_music.mp3');
      unityVisibility.state = false;
    };
    // Start Room Music
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      multimedia.playRoomMusic('music/room_music.mp3');
      // Unity is optional. Keep its startup/error screen from covering the
      // Flutter board when the player has disabled 3D mode.
      ref.read(unityLayerVisibilityProvider.notifier).state =
          ref.read(settingsProvider).is3DModeEnabled;
    });
  }

  late final VoidCallback _restoreLobbyPresentation;

  @override
  void dispose() {
    _confettiController.dispose();
    // Resume Background Music when leaving room
    // Cache dependencies while mounted: WidgetRef is invalid after disposal.
    Future.microtask(_restoreLobbyPresentation);
    super.dispose();
  }

  AppUser _getAvatarUser(WidgetRef ref, MatchState matchState, String currentUserUid, int relativeOffset) {
     if (matchState.playerIds.isEmpty) return AppUser(uid: 'empty', email: '', displayName: 'waiting_label'.tr());
     
     int myIdx = matchState.playerIds.indexOf(currentUserUid);
     
     // spectator logic: if I'm not in the playerIds, I see from Host's perspective (bottom = T1P1)
     int baseIdx = myIdx == -1 ? 0 : myIdx;
     
     // 0 = Bottom (Local Player), 1 = Left, 2 = Top (Opponent), 3 = Right
     if (myIdx != -1 && relativeOffset == 0) {
        final realUser = ref.watch(currentUserProvider);
        if (realUser != null) {
          return realUser.copyWith(displayName: 'you_label'.tr(args: [realUser.displayName]));
        }
     }
     
     int targetIdx = (baseIdx + relativeOffset) % 4;
     if (targetIdx < 0 || targetIdx >= matchState.playerIds.length) {
       return AppUser(uid: 'empty', email: '', displayName: 'waiting_label'.tr());
     }
     
     String targetUid = matchState.playerIds[targetIdx];
     String rawName = matchState.playerNames[targetUid] ?? 
         (targetUid.startsWith('bot_') ? 'bot_name_template' : 'player_default_name');
     
     String targetName;
      if (rawName == 'bot_name_template') {
        final bits = targetUid.split('_');
        final num = bits.length > 1 ? bits[1] : '';
        targetName = '${'bot_name'.tr()} $num';
     } else {
       targetName = rawName.tr();
     }
     
     String avatarUrl = matchState.playerAvatars[targetUid] ?? "";
     
     return AppUser(uid: targetUid, email: '', displayName: targetName, avatarUrl: avatarUrl.isEmpty ? null : avatarUrl);
  }





  String _getTeamOfPlayer(String playerId, List<String> playerIds) {
    final index = playerIds.indexOf(playerId);
    if (index == -1) return '';
    return (index % 2 == 0) ? 'teamA' : 'teamB';
  }

  int _getAbsoluteIndex(MatchState state, String myUid, int offset) {
    int myIdx = state.playerIds.indexOf(myUid);
    if (myIdx == -1) return offset % 4;
    return (myIdx + offset) % 4;
  }


  void _checkWinner(MatchState? state, String myUid) {
    if (state == null) return;
    if (state.phase == GamePhase.matchOver) {
      final myTeamId = _getTeamOfPlayer(myUid, state.playerIds);
      if (myTeamId.isEmpty) return;
      final aWins = state.teamAScore >= state.teamBScore;
      final iWin = aWins == (myTeamId == 'teamA');
      
      if (iWin) {
        _confettiController.play();
        HapticFeedback.vibrate();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchState = ref.watch(matchStateProvider);
    final currentUser = ref.watch(currentUserProvider);

    ref.listen<SettingsState>(settingsProvider, (previous, next) {
      if (previous?.is3DModeEnabled != next.is3DModeEnabled) {
        ref.read(unityLayerVisibilityProvider.notifier).state =
            next.is3DModeEnabled;
      }
    });

    // Effects occur on transition, not on each results rebuild.
    ref.listen<MatchState?>(matchStateProvider, (previous, next) {
      if (next == null) return;
      if (previous?.id != next.id || previous?.roundCount != next.roundCount) {
        // Card IDs repeat on the next deck. Old local tap coordinates must not
        // make a bot's future card appear to arrive from the human's hand.
        ref.read(localPlayOriginsProvider.notifier).state = {};
      }

      // Sync turn timer to Unity when turn or phase changes
      if (next.currentTurnIndex != previous?.currentTurnIndex || next.phase != previous?.phase) {
        if (next.phase == GamePhase.playing) {
          ref.read(unityCommunicationServiceProvider).startTimer(next.timerDurationSeconds);
        }
      }

      if (next.phase == GamePhase.matchOver && previous?.phase != GamePhase.matchOver) {
        if (currentUser != null && !MediaQuery.disableAnimationsOf(context)) {
          _checkWinner(next, currentUser.uid);
        }
        if (currentUser != null) {
          final myTeam = _getTeamOfPlayer(currentUser.uid, next.playerIds);
          final winner = next.teamAScore >= next.teamBScore ? 'teamA' : 'teamB';
          ref.read(multimediaServiceProvider).playSfx(
            myTeam == winner ? 'sfx/win.mp3' : 'sfx/lose.mp3');
        }
      }
    });

    // Room Expiry Check (Hibernation Timeout)
    if (matchState != null && matchState.expireAt != null && DateTime.now().isAfter(matchState.expireAt!)) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('room_expired'.tr()))
           );
           ref.read(matchStateProvider.notifier).leaveMatch();
           _returnToHome();
         }
       });
       return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (matchState == null || currentUser == null) {
      return MatchRecoveryView(
        key: ValueKey(currentUser?.uid ?? 'awaiting-profile'),
        loadingTitle: 'recovery_loading'.tr(),
        unavailableTitle: 'recovery_unavailable'.tr(),
        explanation: 'recovery_explanation'.tr(),
        retryLabel: 'retry_action'.tr(), exitLabel: 'return_home'.tr(),
        onRetry: currentUser == null ? null : () async {
          final result = await ref.read(matchStateProvider.notifier).tryRecoverLastMatch();
          if (!mounted || result == MatchRecoveryStart.listening) return;
          ref.read(matchStateProvider.notifier).leaveMatch();
          final messenger = ScaffoldMessenger.of(context);
          _returnToHome();
          messenger.showSnackBar(SnackBar(content: Text((result == MatchRecoveryStart.offlinePracticeNotSaved
              ? 'recovery_practice_restart' : 'recovery_no_saved_match').tr())));
        },
        onExit: () {
          ref.read(matchStateProvider.notifier).leaveMatch();
          _returnToHome();
        },
      );
    }

    final myUid = currentUser.uid;
    final bool isSpectator = matchState.playerIds.indexOf(myUid) == -1;
    if (matchState.phase == GamePhase.matchOver) {
      return _buildMatchResult(matchState, currentUser, isSpectator);
    }
    final settings = ref.watch(settingsProvider);
    final show3DHand = settings.is3DModeEnabled && ref.watch(unityLayerActiveProvider);


    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _confirmLeave(context, ref);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;
            
            return Stack(
              children: [
                // Background Table (Skin)
                Positioned.fill(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final settings = ref.watch(settingsProvider);
                      final activeTable = ref.watch(activeTableSkinProvider);
                      final is3DActive = settings.is3DModeEnabled && ref.watch(unityLayerActiveProvider);
                      
                      return AnimatedOpacity(
                        duration: is3DActive ? const Duration(milliseconds: 500) : Duration.zero,
                        opacity: is3DActive ? 0.0 : 1.0,
                        child: activeTable.id == 'default_table'
                          ? Image.asset(
                              MediaQuery.sizeOf(context).width < MediaQuery.sizeOf(context).height
                                  ? 'assets/images/tables/lantern_nights_portrait_v2.png'
                                  : 'assets/images/tables/lantern_nights_v1.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const ColoredBox(color: TableStyle.felt),
                            )
                          : activeTable.assetPath.startsWith('http')
                          ? Image.network(
                              activeTable.assetPath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: ThemeConfig.boardGreen),
                            )
                          : Image.asset(
                              activeTable.assetPath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: ThemeConfig.boardGreen),
                            ),
                      );
                    },
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.7),
                      ],
                      radius: 1.2,
                    ),
                  ),
                ),
                
                SafeArea(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildTable(
                        context, ref, matchState, myUid, isLandscape,
                        isSpectator: isSpectator, show3DHand: show3DHand,
                      )),

                    // Overlays
                    if (matchState.phase == GamePhase.waitingForPlayers &&
                        !matchState.id.startsWith('OFFLINE_'))
                      _buildLobbyOverlay(context, ref, matchState, myUid),
                    if (isSpectator && matchState.phase != GamePhase.waitingForPlayers) _buildSpectatorIndicator(),
                    if (matchState.phase == GamePhase.capturing && matchState.board.isEmpty) _buildBasraOverlay(matchState, myUid),
                      
                  ],
                ),
              ),
              
              // Chat Panel
              const ChatOverlay(),

              // Emote Wheel Overlay
              if (_isEmoteWheelOpen)
                Positioned.fill(
                  child: EmoteWheelOverlay(
                    myUid: myUid,
                    onDismiss: () => setState(() => _isEmoteWheelOpen = false),
                  ),
                ),

              // Confetti Celebration
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    ThemeConfig.goldAccent,
                    ThemeConfig.primaryTeal,
                    Colors.white,
                    ThemeConfig.accentPink,
                  ],
                  createParticlePath: _drawStar,
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}


  Widget _buildTable(BuildContext context, WidgetRef ref, MatchState state,
      String myUid, bool isLandscape, {required bool isSpectator, required bool show3DHand}) {
    final myTeam = _getTeamOfPlayer(myUid, state.playerIds);
    final firstIsA = myTeam != 'teamB';
    final playing = state.phase == GamePhase.playing;
    final myTurn = playing && !isSpectator &&
        state.currentTurnIndex == _getAbsoluteIndex(state, myUid, 0);
    final firstLabel = (isSpectator ? 'team_a' : 'my_team').tr();
    final secondLabel = (isSpectator ? 'team_b' : 'table_rivals').tr();

    Widget seat(int offset) {
      final user = _getAvatarUser(ref, state, myUid, offset);
      final active = playing && state.currentTurnIndex == _getAbsoluteIndex(state, myUid, offset);
      final message = ref.watch(lastMessageForUserProvider(user.uid))?.text ??
          _getPlayerEmoji(state, myUid, offset);
      final avatar = TableSeat(
        name: user.uid.startsWith('bot_') ? user.displayName.replaceAll('🤖', '').trim() : user.displayName,
        avatarUrl: user.avatarUrl,
        portraitAsset: offset == 2 ? 'assets/images/avatars/lantern_partner_v1.png' :
          offset == 3 ? 'assets/images/avatars/lantern_rival_man_v1.png' : 'assets/images/avatars/lantern_rival_woman_v1.png',
        accent: offset == 2 ? TableStyle.mint : TableStyle.red,
        dealerLabel: _getAbsoluteIndex(state, myUid, offset) == state.dealerIndex ? 'table_dealer'.tr() : null,
        isBot: user.uid.startsWith('bot_'), active: active,
        detail: active ? 'table_playing'.tr() : 'cards_count'.tr(args: [state.cardsRemainingFor(user.uid).toString()]),
        turnStarted: state.turnStartTime, turnSeconds: state.timerDurationSeconds,
        message: message,
        hiddenHandCount: offset == 0 ? null : state.cardsRemainingFor(user.uid),
        dealIdentity: '${state.id}-${state.roundCount}-${state.handInRound}-${user.uid}',
        dealerDeckKey: _dealerDeckKey, backBuilder: _cardBack,
        onPressed: () => _showPlayerProfile(context, ref, state, myUid, offset),
      );
      return KeyedSubtree(key: _seatKeys[offset], child: DealerSeat(seat: avatar,
        isDealer: _getAbsoluteIndex(state, myUid, offset) == state.dealerIndex,
        compact: offset == 1 || offset == 3,
        remaining: state.deckCount, label: 'table_deal_deck'.tr(),
        deckKey: _getAbsoluteIndex(state, myUid, offset) == state.dealerIndex ? _dealerDeckKey : null,
        backBuilder: _cardBack,
      ));
    }

    return MatchTableLayout(
      header: MatchScoreBar(
        firstLabel: firstLabel, secondLabel: secondLabel,
        firstScore: firstIsA ? state.teamAScore : state.teamBScore,
        secondScore: firstIsA ? state.teamBScore : state.teamAScore,
        details: 'table_round_target'.tr(args: [state.roundCount.toString(), state.maxPoints.toString()]),
        roomLabel: state.id.startsWith('OFFLINE_') ? 'practice_bots'.tr() : state.id,
        onCopyRoom: state.id.startsWith('OFFLINE_') ? null : () {
          Clipboard.setData(ClipboardData(text: state.id));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('room_id_copied'.tr())));
        },
      ),
      partner: seat(2), leftOpponent: seat(3), rightOpponent: seat(1),
      localSeat: state.dealerIndex == _getAbsoluteIndex(state, myUid, 0)
        ? Semantics(key: _seatKeys[0], label: 'table_deal_deck'.tr(), child: Column(
            mainAxisSize: MainAxisSize.min, children: [
              FaceDownStack(key: _dealerDeckKey, count: state.deckCount, backBuilder: _cardBack,
                width: 38, height: 54),
              Text('${state.deckCount}', style: TableStyle.detail.copyWith(color: TableStyle.brass)),
              Text('table_dealer'.tr(), textAlign: TextAlign.center,
                style: TableStyle.detail.copyWith(color: TableStyle.brass, fontWeight: FontWeight.w700)),
            ]))
        : const SizedBox(height: 84),
      collections: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 2, child: TeamCaptureStack(
          captures: state.harvestStacks[firstIsA ? 'teamA' : 'teamB'] ?? const [],
          label: firstLabel,
          countLabel: 'cards_count'.tr(args: [_captureCount(state, firstIsA ? 'teamA' : 'teamB').toString()]),
          latestLabel: 'table_last_capture'.tr(), historyLabel: 'table_view_history'.tr(),
          showLatest: !isSpectator, pileKey: _ourPileKey,
          faceBuilder: _cardFace, backBuilder: _cardBack,
          onHistory: isSpectator ? null : () => _showCaptures(context),
        )),
        const SizedBox(width: 8),
        Expanded(child: TeamCaptureStack(
          captures: state.harvestStacks[firstIsA ? 'teamB' : 'teamA'] ?? const [],
          label: secondLabel,
          countLabel: 'cards_count'.tr(args: [_captureCount(state, firstIsA ? 'teamB' : 'teamA').toString()]),
          latestLabel: '', historyLabel: '', showLatest: false,
          pileKey: _rivalPileKey, accent: TableStyle.red,
          faceBuilder: _cardFace, backBuilder: _cardBack,
        )),
      ]),
      board: SizedBox(key: _boardKey,
        child: _buildBoardCenter(context, ref, state, myUid, isLandscape, is3DActive: show3DHand)),
      status: _buildTableStatus(state, myUid, isSpectator, myTurn),
      hand: isSpectator || show3DHand || (state.handCards[myUid]?.isEmpty ?? true)
        ? const SizedBox(height: 24)
        : FannedHandWidget(
            key: ValueKey('hand-${state.id}-${state.roundCount}-${state.handInRound}'),
            dealerDeckKey: _dealerDeckKey,
            cards: state.handCards[myUid] ?? [], isMyTurn: myTurn,
            interactionEnabled: playing,
            playHint: 'table_play_card'.tr(), queueHint: 'table_queue_card'.tr(),
            cardLabelBuilder: (card) => 'table_card_name'.tr(args: [
              'table_rank_${card.rank.name}'.tr(), 'table_suit_${card.suit.name}'.tr()]),
            onCardTap: (card, globalOrigin) {
              final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
              final origin = box == null || globalOrigin == Offset.zero ? Offset.zero :
                  box.globalToLocal(globalOrigin) - box.size.center(Offset.zero);
              ref.read(matchStateProvider.notifier).playCard(myUid, card, origin: origin);
            },
          ),
      controls: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
        LanternControlButton(label: 'chat'.tr(), icon: Icons.chat_bubble_rounded,
          onPressed: () => ref.read(chatStateProvider.notifier).toggleOverlay()),
        LanternControlButton(label: (ref.watch(settingsProvider).isSoundEnabled ? 'table_sound_on' : 'table_sound_off').tr(),
          icon: ref.watch(settingsProvider).isSoundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          onPressed: () => ref.read(settingsProvider.notifier).toggleSound(!ref.read(settingsProvider).isSoundEnabled)),
        LanternControlButton(label: 'settings'.tr(), icon: Icons.settings_rounded,
          onPressed: () => _showSettings(context)),
        PopupMenuButton<String>(tooltip: 'table_more'.tr(), color: TableStyle.ink,
          icon: const Icon(Icons.more_horiz, color: TableStyle.ivory),
          constraints: const BoxConstraints(minWidth: 160),
          onSelected: (action) {
            switch (action) {
              case 'reactions': setState(() => _isEmoteWheelOpen = !_isEmoteWheelOpen);
              case 'captures': _showCaptures(context);
              case 'leave': _confirmLeave(context, ref);
            }
          },
          itemBuilder: (_) => [
            if (!isSpectator) PopupMenuItem(value: 'reactions', child: Text('table_reactions'.tr(), style: TableStyle.label)),
            if (!isSpectator) PopupMenuItem(value: 'captures', child: Text('table_captures'.tr(), style: TableStyle.label)),
            PopupMenuItem(value: 'leave', child: Text('leave_game_title'.tr(), style: TableStyle.label)),
          ]),
      ])),
    );
  }

  Widget _buildTableStatus(MatchState state, String uid, bool spectator, bool myTurn) {
    if (state.phase == GamePhase.shuffleVoting || state.phase == GamePhase.rematchVoting) {
      final shuffle = state.phase == GamePhase.shuffleVoting;
      final votes = shuffle ? state.shuffleVotes : state.rematchVotes;
      final canVote = !spectator && !votes.containsKey(uid);
      final myTeam = _getTeamOfPlayer(uid, state.playerIds);
      final winner = state.teamAScore >= state.teamBScore ? 'teamA' : 'teamB';
      return MatchChoicePanel(
        key: ValueKey('${state.id}-${state.roundCount}-${state.phase.name}-$uid'),
        title: shuffle ? 'deck_finished'.tr() :
          (spectator ? 'match_over'.tr() :
            (myTeam == winner ? 'your_team_wins' : 'opponent_wins').tr()),
        detail: spectator ? 'you_are_spectating'.tr() :
          votes.containsKey(uid) ? 'waiting_for_other_players'.tr() :
          (shuffle ? 'shuffle_votes' : 'rematch_votes').tr(args: [votes.length.toString()]),
        firstLabel: (shuffle ? 'shuffle_yes' : 'best_of_3_yes').tr(),
        secondLabel: (shuffle ? 'keep_sequence_no' : 'leave_match_no').tr(),
        failureMessage: 'match_action_retry'.tr(), canVote: canVote,
        onFirst: !canVote ? null : () => shuffle
          ? ref.read(matchStateProvider.notifier).voteShuffle(uid, true)
          : ref.read(matchStateProvider.notifier).voteRematch(uid, true),
        onSecond: !canVote ? null : () => shuffle
          ? ref.read(matchStateProvider.notifier).voteShuffle(uid, false)
          : ref.read(matchStateProvider.notifier).voteRematch(uid, false),
      );
    }
    if (state.phase == GamePhase.preRoundCut) {
      final myIndex = state.playerIds.indexOf(uid);
      final canCut = myIndex >= 0 && state.playerIds.isNotEmpty &&
          myIndex == (state.dealerIndex + state.playerIds.length - 1) % state.playerIds.length;
      return MatchPhasePanel(
        key: ValueKey('${state.id}-${state.roundCount}-cut'),
        title: 'pre_round_cut'.tr(),
        message: (canCut ? 'your_turn_cut_deck' : 'waiting_deck_cut').tr(),
        actionLabel: canCut ? 'cut_the_deck'.tr() : null,
        onAction: canCut ? () => ref.read(matchStateProvider.notifier).performCut(20) : null,
        failureMessage: 'match_action_retry'.tr(),
      );
    }
    if (state.phase == GamePhase.dealingCards ||
        state.phase == GamePhase.dealingFasha ||
        state.phase == GamePhase.roundScoring) {
      final title = switch (state.phase) {
        GamePhase.dealingCards => 'memorize_table_cards',
        GamePhase.roundScoring => 'round_finished',
        _ => state.cutLastCard != null ? 'last_card_label' : 'dealing_cards',
      };
      return MatchPhasePanel(
        key: ValueKey('${state.id}-${state.phase.name}'),
        title: title.tr(), message: (state.phase == GamePhase.roundScoring
            ? 'round_advances_automatically' : 'next_phase_automatically').tr(),
        failureMessage: 'match_action_retry'.tr(),
      );
    }
    return LanternTurnBadge(active: myTurn,
      title: spectator ? 'you_are_spectating'.tr() : myTurn ? 'table_your_turn'.tr() :
        state.phase == GamePhase.playing ? 'table_waiting'.tr() : _tablePhaseLabel(state.phase),
      hint: spectator || state.phase != GamePhase.playing ? '' :
        (myTurn ? 'table_play_hint' : 'table_wait_or_queue').tr());
  }

  String _tablePhaseLabel(GamePhase phase) => switch (phase) {
    GamePhase.waitingForPlayers => 'waiting_for_other_players'.tr(),
    GamePhase.preRoundCut => 'table_cutting'.tr(),
    GamePhase.dealingFasha || GamePhase.dealingCards => 'dealing_cards'.tr(),
    GamePhase.capturing => 'table_capturing'.tr(),
    GamePhase.roundScoring => 'table_scoring'.tr(),
    GamePhase.matchOver => 'match_over'.tr(),
    GamePhase.shuffleVoting || GamePhase.rematchVoting => 'waiting_for_other_players'.tr(),
    GamePhase.playing => 'table_wait_or_queue'.tr(),
  };

  Widget _cardFace(game_card.Card card, double width, double height) =>
    CardWidget(card: card, width: width, height: height);

  Widget _cardBack(double width, double height) => CardWidget(
    card: const game_card.Card(game_card.Suit.spades, game_card.Rank.ace),
    isFaceUp: false, width: width, height: height);

  int _captureCount(MatchState state, String team) =>
    (state.harvestStacks[team] ?? const <Capture>[])
      .fold<int>(0, (count, capture) => count + capture.cardCount);

  void _showCaptures(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: TableStyle.ivory, isScrollControlled: true,
      builder: (context) => SafeArea(child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.65,
        // Read live state: an open sheet must clear when the next round starts.
        child: Consumer(builder: (context, ref, _) {
          final current = ref.watch(matchStateProvider);
          final uid = ref.watch(currentUserProvider)?.uid;
          final team = current == null || uid == null ? '' :
            _getTeamOfPlayer(uid, current.playerIds);
          return CaptureCardHistory(
            captures: current?.harvestStacks[team] ?? const [],
            title: 'table_capture_cards'.tr(),
            explanation: 'table_capture_history_help'.tr(),
            emptyLabel: 'table_no_captures'.tr(), faceBuilder: _cardFace,
            statusLabel: current?.phase == GamePhase.playing &&
                    current!.playerIds.indexOf(uid ?? '') == current.currentTurnIndex
                ? 'table_your_turn'.tr() : 'table_waiting'.tr(),
            latestLabel: 'table_latest'.tr(), backLabel: 'table_back_to_table'.tr(),
            cardLabel: (card) => 'table_card_name'.tr(args: [
              'table_rank_${card.rank.name}'.tr(), 'table_suit_${card.suit.name}'.tr()]),
          );
        }),
      )),
    );
  }

  Path _drawStar(Size size) {
    double degToRad(double deg) => deg * (pi / 180.0);
    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * cos(step),
          halfWidth + externalRadius * sin(step));
      path.lineTo(halfWidth + internalRadius * cos(step + halfDegreesPerStep),
          halfWidth + internalRadius * sin(step + halfDegreesPerStep));
    }
    path.close();
    return path;
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SettingsOverlay(),
    );
  }

  void _confirmLeave(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.white10),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            const SizedBox(width: 12),
            Text(
              'leave_game_title'.tr(),
              style: const TextStyle(color: Colors.white, fontFamily: ThemeConfig.fontHeading),
            ),
          ],
        ),
        content: Text(
          'leave_game_warning'.tr(),
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr(), style: const TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              ref.read(matchStateProvider.notifier).leaveMatch();
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit Game Screen
            },
            child: Text(
              'leave'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String? _getPlayerEmoji(MatchState matchState, String myUid, int offset) {
    final idx = _getAbsoluteIndex(matchState, myUid, offset);
    if (matchState.playerIds.length > idx) {
      return matchState.playerEmojis[matchState.playerIds[idx]];
    }
    return null;
  }

  Widget _buildBoardCenter(
    BuildContext context, 
    WidgetRef ref, 
    MatchState matchState, 
    String myUid, 
    bool isLandscape, 
    {bool is3DActive = false}
  ) {
    if (is3DActive) {
      return const SizedBox.shrink();
    }

    if (matchState.phase == GamePhase.dealingFasha && matchState.cutLastCard != null) {
      return Center(child: CardWidget(card: matchState.cutLastCard!, width: 96, height: 138));
    }
    final isCapturing = matchState.phase == GamePhase.capturing;
    final collector = matchState.capturingTeam;
    final viewerTeam = _getTeamOfPlayer(myUid, matchState.playerIds);
    final collectorLabel = collector == null ? null :
        (viewerTeam.isEmpty
          ? (collector == 'teamA' ? 'team_a' : 'team_b')
          : (collector == viewerTeam ? 'my_team' : 'opponent_team')).tr();
    final capturedCount = matchState.capturingCards.isNotEmpty
        ? matchState.capturingCards.length : matchState.board.length;
    final localOrigins = ref.watch(localPlayOriginsProvider);
    final myIndex = matchState.playerIds.indexOf(myUid);
    final baseIndex = myIndex < 0 ? 0 : myIndex;
    Offset seatOrigin(game_card.Card card) {
      final recorded = localOrigins[card.firebaseKey];
      if (recorded != null && recorded != Offset.zero) return recorded;
      final owner = matchState.cardOwnership[card.firebaseKey];
      final ownerIndex = owner == null ? -1 : matchState.playerIds.indexOf(owner);
      final relative = ownerIndex < 0
          ? (isCapturing ? (matchState.currentTurnIndex - baseIndex + 4) % 4 : 2)
          : (ownerIndex - baseIndex + 4) % 4;
      final measured = _seatOffset(relative);
      if (measured != null) {
        return measured;
      }
      return switch (relative) {
        0 => const Offset(0, 150),
        1 => const Offset(150, 0),
        2 => const Offset(0, -140),
        _ => const Offset(-150, 0),
      };
    }

    return BoardCardsWidget(
      key: ValueKey('board-${matchState.id}'),
      cards: matchState.board,
      isLandscape: isLandscape,
      isCapturing: isCapturing,
      capturingTeam: matchState.capturingTeam,
      capturingStage: matchState.capturingStage,
      arrivalOffsets: {
        for (final card in matchState.board) card.firebaseKey: seatOrigin(card),
      },
      captureToBottom: matchState.capturingTeam ==
          (_getTeamOfPlayer(myUid, matchState.playerIds).isEmpty
              ? 'teamA' : _getTeamOfPlayer(myUid, matchState.playerIds)),
      backBuilder: _cardBack,
      captureOffset: _captureDestination(matchState, myUid),
      captureLabel: isCapturing && collectorLabel != null
          ? '$collectorLabel · ${'cards_count'.tr(args: [capturedCount.toString()])}'
          : null,
    );
  }

  Offset? _seatOffset(int relative) => _offsetFromBoard(_seatKeys[relative]);

  Offset? _offsetFromBoard(GlobalKey key) {
    return tableMotionOffset(key, _boardKey);
  }

  Offset? _captureDestination(MatchState state, String uid) {
    final viewer = _getTeamOfPlayer(uid, state.playerIds);
    return _offsetFromBoard(state.capturingTeam == (viewer.isEmpty ? 'teamA' : viewer)
        ? _ourPileKey : _rivalPileKey);
  }

  Widget _buildBasraOverlay(MatchState matchState, String myUid) {
    final capturingTeam = matchState.capturingTeam ?? 'teamA';
    final myTeam = _getTeamOfPlayer(myUid, matchState.playerIds);
    return Positioned.fill(
      child: BasraCelebrationOverlay(
        capturingTeam: capturingTeam,
        isMyTeam: myTeam == capturingTeam,
        onDismissed: () {},
      ),
    );
  }









  Widget _buildLobbyOverlay(BuildContext context, WidgetRef ref, MatchState state, String currentUid) {
    final humans = state.playerIds.where((id) =>
      !id.startsWith('waiting_') && !id.startsWith('bot_')).toList();
    final ready = humans.where((id) => state.botInjectionVotes[id] == true).length;
    return Align(alignment: Alignment.bottomCenter,
      child: Padding(padding: const EdgeInsets.all(12),
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.82),
          child: SingleChildScrollView(child: MatchWaitingRoomPanel(
            roomId: state.id, currentUid: currentUid,
            title: 'waiting_for_players'.tr(),
            roomLabel: 'room_id_label'.tr(args: ['']).trim(),
            waitingLabel: 'waiting_label'.tr(), youLabel: 'you'.tr(),
            botLabel: 'bot_name'.tr(), playerLabel: 'player_default_name'.tr(),
            readyLabel: 'ready_fill_bots'.tr(),
            consentLabel: 'waiting_human_consent'.tr(args: [
              ready.toString(), humans.length.toString()]),
            fullLabel: 'room_full_starting'.tr(),
            spectatorLabel: 'you_are_spectating'.tr(),
            inviteLabel: 'invite_friends'.tr(),
            failureLabel: 'match_action_retry'.tr(),
            playerIds: state.playerIds, playerNames: state.playerNames,
            botVotes: state.botInjectionVotes,
            onInvite: () => _showInviteFriendDialog(context, ref, state, currentUid),
            onReady: () => ref.read(matchStateProvider.notifier).voteForBots(currentUid),
          )),
        ),
      ),
    );
  }

  Widget _buildMatchResult(MatchState state, AppUser user, bool spectator) {
    final myTeam = _getTeamOfPlayer(user.uid, state.playerIds);
    final firstIsA = myTeam != 'teamB';
    final winner = state.teamAScore >= state.teamBScore ? 'teamA' : 'teamB';
    final won = myTeam == winner;
    final offline = state.id.startsWith('OFFLINE_');
    return MatchResultView(
      title: spectator ? 'match_over'.tr() : (won ? 'victory' : 'defeat').tr(),
      subtitle: spectator ? 'you_are_spectating'.tr() : (won ? 'great_play' : 'better_luck').tr(),
      firstTeam: (spectator ? 'team_a' : 'my_team').tr(),
      secondTeam: (spectator ? 'team_b' : 'opponent_team').tr(),
      firstScore: firstIsA ? state.teamAScore : state.teamBScore,
      secondScore: firstIsA ? state.teamBScore : state.teamAScore,
      stars: state.earnedStars[user.uid] ?? 0,
      coins: state.earnedCoins[user.uid] ?? 0,
      starsLabel: 'stars_label'.tr(), coinsLabel: 'coins_label'.tr(),
      homeLabel: 'return_home'.tr(), replayLabel: 'play_again'.tr(),
      onReplay: offline && !spectator ? () => ref.read(matchStateProvider.notifier)
        .startOfflinePracticeMatch(user.uid, user.displayName,
          mode: state.mode, maxPoints: state.maxPoints) : null,
      onHome: () {
        ref.read(matchStateProvider.notifier).leaveMatch();
        _returnToHome();
      },
    );
  }
  void _showInviteFriendDialog(BuildContext context, WidgetRef ref, MatchState state, String currentUid) {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('invite_friends'.tr(), style: const TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: currentUser.friends.isEmpty 
              ? Text('no_friends_yet'.tr(), style: const TextStyle(color: Colors.white70))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: currentUser.friends.length,
                  itemBuilder: (context, index) {
                    final friendId = currentUser.friends[index];
                    return FutureBuilder<List<AppUser>>(
                      future: ref.read(multiplayerSyncServiceProvider).searchUsers(friendId),
                      builder: (context, snap) {
                        final friend = snap.data?.firstWhere((u) => u.uid == friendId, orElse: () => AppUser(uid: friendId, email: '', displayName: 'player_default_name'.tr()));
                        return ListTile(
                          title: Text(friend?.displayName ?? 'player_default_name'.tr(), style: const TextStyle(color: Colors.white)),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                            child: Text('send'.tr()),
                            onPressed: () async {
                              try {
                                await ref.read(multiplayerSyncServiceProvider).sendInvite(friendId, state.id);
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('invitation_sent'.tr())));
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(ErrorHandler.getAuthErrorMessage(e))),
                                );
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
          ),
        );
      },
    );
  }

  Widget _buildSpectatorIndicator() {
    return Positioned(
      top: 100,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ThemeConfig.goldAccent.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility_outlined, color: ThemeConfig.goldAccent, size: 16),
            const SizedBox(width: 8),
            Text(
              'spectating_label'.tr().toUpperCase(),
              style: const TextStyle(color: ThemeConfig.goldAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlayerProfile(BuildContext context, WidgetRef ref, MatchState matchState, String myUid, int offset) {
    if (matchState.playerIds.isEmpty) return;
    
    final absoluteIndex = _getAbsoluteIndex(matchState, myUid, offset);
    final targetPlayerId = matchState.playerIds[absoluteIndex % matchState.playerIds.length];
    
    // Don't show for bots
    if (targetPlayerId.startsWith('bot_')) return;
    
    final user = _getAvatarUser(ref, matchState, myUid, offset);
    
    showDialog(
      context: context,
      builder: (context) => PlayerProfilePreview(user: user),
    );
  }
}

