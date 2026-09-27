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
import '../widgets/match_summary_dialog.dart';
import '../widgets/board_cards_widget.dart';
import '../widgets/match_table_layout.dart';
import '../widgets/table_seat.dart';
import '../widgets/table_style.dart';
import '../widgets/basra_celebration_overlay.dart';
import '../widgets/emote_wheel_overlay.dart';
import 'package:flutter/services.dart';
import 'package:halabessa/core/services/multimedia_service.dart';
import 'package:halabessa/core/utils/error_handler.dart';
import '../widgets/unity_game_view.dart';
import '../providers/unity_communication_service.dart';
import '../providers/unity_layer_provider.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import 'dart:convert';

class GameBoardScreen extends ConsumerStatefulWidget {
  const GameBoardScreen({super.key});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen> {
  late ConfettiController _confettiController;
  final GlobalKey _boardKey = GlobalKey();
  bool _isEmoteWheelOpen = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    
    // Start Room Music
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(multimediaServiceProvider).playRoomMusic('music/room_music.mp3');
      // Unity is optional. Keep its startup/error screen from covering the
      // Flutter board when the player has disabled 3D mode.
      ref.read(unityLayerVisibilityProvider.notifier).state =
          ref.read(settingsProvider).is3DModeEnabled;
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    // Resume Background Music when leaving room
    Future.microtask(() {
      ref.read(multimediaServiceProvider).playMusic('music/bg_music.mp3');
      ref.read(unityLayerVisibilityProvider.notifier).state = false;
    });
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

    // Match Over Rewards Popup
    ref.listen<MatchState?>(matchStateProvider, (previous, next) {
      if (next == null) return;

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
        final winnerTeam = next!.teamAScore >= next.teamBScore ? 'teamA' : 'teamB';
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => MatchSummaryDialog(
            matchState: next,
            winnerTeam: winnerTeam,
          ),
        );
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
           Navigator.of(context).popUntil((route) => route.isFirst);
         }
       });
       return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (matchState == null || currentUser == null) {
      if (currentUser != null && matchState == null) {
        Future.microtask(() => ref.read(matchStateProvider.notifier).tryRecoverLastMatch());
      }

      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Color(0xFF1B263B),
                ThemeConfig.darkBg,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with subtle scale
                Image.asset(
                  'assets/images/logo.png',
                  height: 140,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.casino, size: 80, color: ThemeConfig.goldAccent),
                ),
                const SizedBox(height: 60),
                // Glowing Loader
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: ThemeConfig.goldAccent.withOpacity(0.3),
                            blurRadius: 25,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 45,
                      height: 45,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(ThemeConfig.goldAccent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text(
                  'loading_match_environment'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontFamily: ThemeConfig.fontHeading,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(color: Colors.black87, offset: Offset(0, 2), blurRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(height: 64),
                _buildRetryButton(context, ref),
              ],
            ),
          ),
        ),
      );
    }

    final myUid = currentUser.uid;
    final bool isSpectator = matchState.playerIds.indexOf(myUid) == -1;
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
                          ? const ColoredBox(color: TableStyle.felt)
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
                    if (matchState.phase == GamePhase.waitingForPlayers) _buildLobbyOverlay(context, ref, matchState, myUid),
                    if (isSpectator && matchState.phase != GamePhase.waitingForPlayers) _buildSpectatorIndicator(),
                    if (matchState.phase == GamePhase.preRoundCut) _buildCutOverlay(context, ref, matchState, myUid),
                    if (matchState.phase == GamePhase.dealingFasha && matchState.cutLastCard != null)
                       _buildLastCardReveal(matchState.cutLastCard!),
                    if (matchState.phase == GamePhase.dealingFasha && matchState.cutLastCard == null) _buildPhaseOverlay('dealing_cards'.tr()),
                    if (matchState.phase == GamePhase.dealingCards) _buildPhaseOverlay('memorize_fasha'.tr(args: ['5']), alignment: const Alignment(0, -0.4)),
                    if (matchState.phase == GamePhase.shuffleVoting) _buildShuffleVoteOverlay(context, ref, matchState, myUid),
                    if (matchState.phase == GamePhase.roundScoring) _buildContextualScoringOverlay(matchState, myUid),
                    if (matchState.phase == GamePhase.rematchVoting) _buildRematchVoteOverlay(context, ref, matchState, myUid),
                    if (matchState.phase == GamePhase.matchOver) _buildContextualGameOverOverlay(matchState, myUid),
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
    final secondLabel = (isSpectator ? 'team_b' : 'opponent_team').tr();

    Widget seat(int offset) {
      final user = _getAvatarUser(ref, state, myUid, offset);
      final active = playing && state.currentTurnIndex == _getAbsoluteIndex(state, myUid, offset);
      final message = ref.watch(lastMessageForUserProvider(user.uid))?.text ??
          _getPlayerEmoji(state, myUid, offset);
      return TableSeat(
        name: user.displayName, avatarUrl: user.avatarUrl,
        isBot: user.uid.startsWith('bot_'), active: active,
        detail: active ? 'table_playing'.tr() : 'cards_count'.tr(args: [state.cardsRemainingFor(user.uid).toString()]),
        turnStarted: state.turnStartTime, turnSeconds: state.timerDurationSeconds,
        message: message,
        onPressed: () => _showPlayerProfile(context, ref, state, myUid, offset),
      );
    }

    return MatchTableLayout(
      header: MatchScoreBar(
        firstLabel: firstLabel, secondLabel: secondLabel,
        firstScore: firstIsA ? state.teamAScore : state.teamBScore,
        secondScore: firstIsA ? state.teamBScore : state.teamAScore,
        details: 'table_round_target'.tr(args: [state.roundCount.toString(), state.maxPoints.toString()]),
        roomLabel: state.id,
        onCopyRoom: () {
          Clipboard.setData(ClipboardData(text: state.id));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('room_id_copied'.tr())));
        },
      ),
      partner: seat(2), leftOpponent: seat(3), rightOpponent: seat(1),
      board: SizedBox(key: _boardKey,
        child: _buildBoardCenter(context, ref, state, myUid, isLandscape, is3DActive: show3DHand)),
      status: Semantics(liveRegion: true, child: Text(
        isSpectator ? 'you_are_spectating'.tr() : myTurn ? 'table_tap_to_play'.tr() :
          playing ? 'table_wait_or_queue'.tr() : _tablePhaseLabel(state.phase),
        textAlign: TextAlign.center,
        style: TableStyle.label.copyWith(color: myTurn ? TableStyle.brass : TableStyle.ivory),
      )),
      hand: isSpectator || show3DHand || (state.handCards[myUid]?.isEmpty ?? true)
        ? const SizedBox(height: 24)
        : FannedHandWidget(
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
      controls: Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
        IconButton(tooltip: 'chat'.tr(), icon: const Icon(Icons.chat_bubble_outline),
          color: TableStyle.ivory, constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: () => ref.read(chatStateProvider.notifier).toggleOverlay()),
        if (!isSpectator) IconButton(tooltip: 'table_reactions'.tr(), icon: const Icon(Icons.emoji_emotions_outlined),
          color: TableStyle.ivory, constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: () => setState(() => _isEmoteWheelOpen = !_isEmoteWheelOpen)),
        IconButton(tooltip: 'table_captures'.tr(), icon: const Icon(Icons.layers_outlined),
          color: TableStyle.ivory, constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: () => _showCaptures(context, state)),
        IconButton(tooltip: 'settings'.tr(), icon: const Icon(Icons.settings_outlined),
          color: TableStyle.ivory, constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: () => _showSettings(context)),
        IconButton(tooltip: 'leave_game_title'.tr(), icon: const Icon(Icons.logout_rounded),
          color: TableStyle.ivory, constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: () => _confirmLeave(context, ref)),
      ]),
    );
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

  void _showCaptures(BuildContext context, MatchState state) {
    showModalBottomSheet(
      context: context, backgroundColor: TableStyle.ink, isScrollControlled: true,
      builder: (context) => SafeArea(child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: Column(children: [
          ListTile(title: Text('table_captures'.tr(), style: TableStyle.label),
            trailing: IconButton(tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(Icons.close, color: TableStyle.ivory),
              onPressed: () => Navigator.pop(context))),
          Expanded(child: ListView(children: [
            for (final team in ['teamA', 'teamB']) ...[
              Padding(padding: const EdgeInsets.all(16),
                child: Text((team == 'teamA' ? 'team_a' : 'team_b').tr(), style: TableStyle.label)),
              if ((state.harvestStacks[team] ?? []).isEmpty)
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('table_no_captures'.tr(), style: TableStyle.detail)),
              for (final capture in state.harvestStacks[team] ?? <Capture>[])
                Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final card in capture.capturedCards)
                      Semantics(label: 'table_card_name'.tr(args: [
                        'table_rank_${card.rank.name}'.tr(), 'table_suit_${card.suit.name}'.tr()]),
                        child: CardWidget(card: card, width: 48, height: 68)),
                  ])),
            ],
          ])),
        ]),
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

  Widget _buildMiniBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 9,
          fontWeight: FontWeight.w600,
          fontFamily: ThemeConfig.fontBody,
        ),
      ),
    );
  }




  Widget _buildRetryButton(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          backgroundColor: Colors.white.withOpacity(0.05),
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        onPressed: () {
            final lastId = ref.read(matchStateProvider.notifier).lastBoundMatchId;
            if (lastId != null) {
               ref.read(matchStateProvider.notifier).rebind(lastId);
            } else {
               ref.read(matchStateProvider.notifier).leaveMatch();
               Navigator.of(context).popUntil((route) => route.isFirst);
            }
        },
        child: Text(
          'retry_or_exit'.tr().toUpperCase(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
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

    final isCapturing = matchState.phase == GamePhase.capturing;

    return BoardCardsWidget(
      cards: matchState.board,
      isLandscape: isLandscape,
      isCapturing: isCapturing,
      capturingTeam: matchState.capturingTeam,
      capturingStage: matchState.capturingStage,
    );
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


  Widget _buildLastCardReveal(game_card.Card card) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.5 + (0.5 * value),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ThemeConfig.goldAccent.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: ThemeConfig.goldAccent.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                'last_card_label'.tr(),
                style: const TextStyle(
                  color: ThemeConfig.goldAccent,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: ThemeConfig.fontHeading,
                ),
              ),
            ),
            const SizedBox(height: 24),
            CardWidget(card: card, width: 140, height: 210),
          ],
        ),
      ),
    );
  }


  Widget _buildPhaseOverlay(String text, {Alignment alignment = Alignment.center}) {
    return Align(
      alignment: alignment,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 4)
          ],
        ),
        child: Text(
          text, 
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2)
        ),
      ),
    );
  }

  Widget _buildContextualScoringOverlay(MatchState matchState, String myUid) {
    // Premium Round Summary Overlay
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('round_finished'.tr(), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: ThemeConfig.fontHeading)),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildScoringTeamCard('my_team'.tr(), matchState.harvestStacks['teamA']?.fold<int>(0, (sum, cap) => sum + cap.capturedCards.length + 1) ?? 0, ThemeConfig.primaryTeal),
                _buildScoringTeamCard('opponent_team'.tr(), matchState.harvestStacks['teamB']?.fold<int>(0, (sum, cap) => sum + cap.capturedCards.length + 1) ?? 0, ThemeConfig.goldAccent),
              ],
            ),
            const SizedBox(height: 64),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => ref.read(matchStateProvider.notifier).startNewRound(),
              child: Text('next_round'.tr().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoringTeamCard(String title, int count, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 12),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5), width: 4),
            boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)],
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(color: color, fontSize: 48, fontWeight: FontWeight.bold, fontFamily: ThemeConfig.fontHeading),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('total_cards'.tr(), style: TextStyle(color: color.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }


  Widget _buildCutOverlay(BuildContext context, WidgetRef ref, MatchState state, String currentUid) {
    int myIdx = state.playerIds.indexOf(currentUid);
    int cutterIdx = (state.dealerIndex + 3) % 4;
    bool isMyCut = myIdx == cutterIdx;
    
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9), 
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('pre_round_cut'.tr(), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(isMyCut ? 'your_turn_cut_deck'.tr() : 'waiting_deck_cut'.tr(), 
              style: const TextStyle(color: Colors.white70, fontSize: 16)
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isMyCut ? Colors.teal : Colors.blueGrey,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => ref.read(matchStateProvider.notifier).performCut(20),
              child: Text(isMyCut ? 'cut_the_deck'.tr() : 'wait_for_cut'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLobbyOverlay(BuildContext context, WidgetRef ref, MatchState state, String currentUid) {
    final isReady = state.botInjectionVotes.containsKey(currentUid);
    final readyCount = state.botInjectionVotes.length;
    // Count only real humans (not placeholders)
    final myIdx = state.playerIds.indexOf(currentUid);
    final isSpectator = myIdx == -1;
    final humanCount = state.playerIds.where((id) => !id.startsWith('waiting_')).length;

    
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        width: 340,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9), 
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isSpectator ? 'spectating_label'.tr() : 'waiting_for_players'.tr(), 
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                   const Icon(Icons.hub, color: Colors.orangeAccent, size: 20),
                   const SizedBox(width: 12),
                   Text('room_id_label'.tr(args: [state.id]), 
                     style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)
                   ),
                   const Spacer(),
                   if (!isSpectator)
                     IconButton(
                       icon: const Icon(Icons.share, color: Colors.tealAccent, size: 20),
                       onPressed: () => _showInviteFriendDialog(context, ref, state, currentUid),
                     ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ...state.playerIds.map((id) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                   CircleAvatar(
                     radius: 12,
                     backgroundColor: id == currentUid ? Colors.green : Colors.white10,
                     child: Icon(id.startsWith('waiting_') ? Icons.hourglass_empty : Icons.person, size: 14, color: id == currentUid ? Colors.white : Colors.white38),
                   ),
                   const SizedBox(width: 12),
                   Text(id == currentUid ? "you".tr() : (id.startsWith('waiting_') ? "waiting_label".tr() : (state.playerNames[id] ?? "player_default_name".tr())), 
                     style: TextStyle(color: id == currentUid ? Colors.green : Colors.white70)
                   ),
                   const Spacer(),
                   if (state.botInjectionVotes.containsKey(id))
                     const Icon(Icons.check_circle, color: Colors.green, size: 18),
                ],
              ),
            )),
            const SizedBox(height: 32),
            if (!isSpectator) ...[
              if (humanCount < 4) ...[
                if (!isReady)
                  ElevatedButton.icon(
                    onPressed: () => ref.read(matchStateProvider.notifier).voteForBots(currentUid),
                    icon: const Icon(Icons.smart_toy),
                    label: Text('ready_fill_bots'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                else
                  Text('waiting_human_consent'.tr(args: [readyCount.toString(), humanCount.toString()]), 
                    style: const TextStyle(color: Colors.orangeAccent, fontStyle: FontStyle.italic, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
              ] else
                Text('room_full_starting'.tr(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ] else 
              Text('you_are_spectating'.tr(), style: const TextStyle(color: ThemeConfig.goldAccent, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _buildShuffleVoteOverlay(BuildContext context, WidgetRef ref, MatchState state, String currentUid) {
    final hasVoted = state.shuffleVotes.containsKey(currentUid);
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.9), borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('deck_finished'.tr(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('shuffle_votes'.tr(args: [state.shuffleVotes.length.toString()]), style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 32),
            if (!hasVoted) Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: () => ref.read(matchStateProvider.notifier).voteShuffle(currentUid, true),
                  child: Text('shuffle_yes'.tr()),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                  onPressed: () => ref.read(matchStateProvider.notifier).voteShuffle(currentUid, false),
                  child: Text('keep_sequence_no'.tr()),
                ),
              ],
            ) else Text('waiting_for_other_players'.tr(), style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildContextualGameOverOverlay(MatchState state, String currentUid) {
    final bool aWins = state.teamAScore >= state.teamBScore;
    final winnerTeam = aWins ? 'teamA' : 'teamB';
    final isOffline = state.id.startsWith('OFFLINE_');
    final currentUser = ref.read(currentUserProvider);
    
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF141A29),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: ThemeConfig.goldAccent.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 30, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'match_over'.tr().toUpperCase(),
                style: const TextStyle(
                  fontFamily: ThemeConfig.fontHeading,
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${state.teamAScore} - ${state.teamBScore}',
                style: const TextStyle(
                  fontFamily: ThemeConfig.fontHeading,
                  color: ThemeConfig.goldAccent,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              // Play Again Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.goldAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.replay_rounded, size: 20),
                  label: Text('play_again'.tr().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  onPressed: () {
                    if (isOffline) {
                      ref.read(matchStateProvider.notifier).startOfflinePracticeMatch(
                        currentUser?.uid ?? 'player',
                        currentUser?.displayName ?? 'Player',
                      );
                    } else {
                      ref.read(matchStateProvider.notifier).voteRematch(currentUid, true);
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              // View Results Button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.bar_chart_rounded, size: 18),
                  label: Text('view_results'.tr()),
                  onPressed: () {
                    showGeneralDialog(
                      context: context,
                      barrierDismissible: false,
                      barrierLabel: '',
                      pageBuilder: (context, anim1, anim2) => MatchSummaryDialog(matchState: state, winnerTeam: winnerTeam),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              // Return to Home
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white60,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.home_rounded, size: 18),
                  label: Text('return_home'.tr()),
                  onPressed: () {
                    ref.read(matchStateProvider.notifier).leaveMatch();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    ref.read(multimediaServiceProvider).playMusic('music/bg_music.mp3');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRematchVoteOverlay(BuildContext context, WidgetRef ref, MatchState state, String currentUid) {
    final hasVoted = state.rematchVotes.containsKey(currentUid);
    final bool aWins = state.teamAScore >= state.teamBScore;
    final myTeamId = _getTeamOfPlayer(currentUid, state.playerIds);
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.9), borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('match_over'.tr(), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            Text(aWins == (myTeamId == 'teamA') ? 'your_team_wins'.tr() : 'opponent_wins'.tr(), style: const TextStyle(color: Colors.amberAccent, fontSize: 20)),
            const SizedBox(height: 32),
            if (!hasVoted) Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: () => ref.read(matchStateProvider.notifier).voteRematch(currentUid, true),
                  child: Text('best_of_3_yes'.tr()),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                  onPressed: () => ref.read(matchStateProvider.notifier).voteRematch(currentUid, false),
                  child: Text('leave_match_no'.tr()),
                ),
              ],
            ) else Text('waiting_for_other_players'.tr(), style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
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

