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
import 'package:halabessa/features/game/presentation/widgets/player_avatar.dart';
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
import '../widgets/harvest_piles_widget.dart';
import '../widgets/match_summary_dialog.dart';
import '../widgets/board_cards_widget.dart';
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
      ref.read(unityLayerVisibilityProvider.notifier).state = true;
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

  Widget _buildTeamHarvestPiles(MatchState matchState, String teamId, {required bool isMyTeam}) {
    final captures = matchState.harvestStacks[teamId] ?? [];
    if (captures.isEmpty) return const SizedBox.shrink();

    // Alignment: 
    // Team A (Partner) -> Top Left area (beside top avatar)
    // Team B (Opponents) -> Mid Right area
    final alignment = teamId == 'teamA' 
        ? const Alignment(-0.8, -0.7) // Top left-ish
        : const Alignment(0.8, -0.4); // Mid right-ish

    return Align(
      alignment: alignment,
      child: HarvestPilesWidget(
        captures: captures, 
        teamName: isMyTeam ? 'my_team'.tr() : 'opponent_team'.tr(),
        isMyTeam: isMyTeam,
      ),
    );
  }

  Widget _buildFloatingMatchStatus(MatchState matchState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMatchStatusRow(Icons.refresh, 'round_label'.tr(args: [matchState.roundCount.toString()])),
          const SizedBox(width: 16),
          _buildMatchStatusRow(Icons.layers_outlined, 'hand_label'.tr(args: [matchState.handInRound.toString()])),
          const SizedBox(width: 16),
          _buildMatchStatusRow(Icons.style_outlined, 'cards_count'.tr(args: [matchState.handCards[matchState.playerIds[matchState.currentTurnIndex % matchState.playerIds.length]]?.length.toString() ?? '0'])),
        ],
      ),
    );
  }

  Widget _buildFloatingMatchStatusSmall(MatchState matchState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMatchStatusRow(Icons.refresh, matchState.roundCount.toString()),
          const SizedBox(width: 10),
          _buildMatchStatusRow(Icons.layers_outlined, '${matchState.handInRound}/3'),
          const SizedBox(width: 10),
          _buildMatchStatusRow(Icons.style_outlined, matchState.handCards[matchState.playerIds[matchState.currentTurnIndex % matchState.playerIds.length]]?.length.toString() ?? '0'),
        ],
      ),
    );
  }

  Widget _buildMatchStatusRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: ThemeConfig.goldAccent.withOpacity(0.8), size: 14),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
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

  Color? _getTeamColorForOffset(MatchState state, String myUid, int offset) {
    if (state.playerIds.isEmpty) return null;
    final absIdx = _getAbsoluteIndex(state, myUid, offset);
    if (absIdx >= state.playerIds.length) return null;
    
    final team = _getTeamOfPlayer(state.playerIds[absIdx], state.playerIds);
    return team == 'teamA' ? ThemeConfig.primaryTeal : ThemeConfig.goldAccent;
  }

  void _checkWinner(MatchState? state, String myUid) {
    if (state == null) return;
    if (state.phase == GamePhase.matchOver) {
      final myTeamId = _getTeamOfPlayer(myUid, state.playerIds);
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

    // Trigger celebration if match is over and we won
    if (currentUser != null) {
      _checkWinner(matchState, currentUser.uid);
    }

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
    final isUnityVisible = ref.watch(unityLayerVisibilityProvider);
    final isUnityInitialized = ref.watch(unityInitializedProvider);
    final show3DHand = settings.is3DModeEnabled && isUnityVisible && isUnityInitialized;


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
            
            // Auto-trigger confetti on match over win
            if (matchState.phase == GamePhase.matchOver) {
              final myIndex = matchState.playerIds.indexOf(myUid);
              if (myIndex != -1) {
                final myTeam = (myIndex == 0 || myIndex == 2) ? 'teamA' : 'teamB';
                final aWins = matchState.teamAScore >= matchState.teamBScore;
                final winnerTeam = aWins ? 'teamA' : 'teamB';
                if (myTeam == winnerTeam && _confettiController.state != ConfettiControllerState.playing) {
                  _confettiController.play();
                }
              }
            }

            return Stack(
              children: [
                // Background Table (Skin)
                Positioned.fill(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final settings = ref.watch(settingsProvider);
                      final activeTable = ref.watch(activeTableSkinProvider);
                      final isUnityVisible = ref.watch(unityLayerVisibilityProvider);
                      final isUnityInitialized = ref.watch(unityInitializedProvider);
                      final is3DActive = settings.is3DModeEnabled && isUnityVisible && isUnityInitialized;
                      
                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 500),
                        opacity: is3DActive ? 0.0 : 1.0,
                        child: activeTable.assetPath.startsWith('http')
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
                      // New Top Bar (Persistent)
                      _buildTopBar(context, ref, matchState, isLandscape),
                    
                    // ... Players and Board Center next ...
                    // Partner / Opposite Player (Offset 2 in Anticlockwise)
                    Align(
                      alignment: isLandscape ? const Alignment(0, -0.9) : Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: isLandscape ? 0 : 10.0), 
                        child: GestureDetector(
                          onTap: () => _showPlayerProfile(context, ref, matchState, myUid, 2),
                          child: PlayerAvatar(
                            user: _getAvatarUser(ref, matchState, myUid, 2),
                            isCurrentTurn: matchState.currentTurnIndex == _getAbsoluteIndex(matchState, myUid, 2),
                            turnStartTime: matchState.turnStartTime,
                            timerDurationSeconds: matchState.timerDurationSeconds,
                            activeEmoji: _getPlayerEmoji(matchState, myUid, 2),
                            activeMessage: ref.watch(lastMessageForUserProvider(matchState.playerIds.isEmpty ? '' : matchState.playerIds[(_getAbsoluteIndex(matchState, myUid, 2)) % matchState.playerIds.length]))?.text,
                            teamColor: _getTeamColorForOffset(matchState, myUid, 2),
                          ),
                        ),
                      ),
                    ),

                    // Left Player (Offset 3 in Anticlockwise)
                    Align(
                      alignment: isLandscape ? const Alignment(-0.95, 0.2) : const Alignment(-0.95, -0.15),
                      child: GestureDetector(
                        onTap: () => _showPlayerProfile(context, ref, matchState, myUid, 3),
                        child: PlayerAvatar(
                          user: _getAvatarUser(ref, matchState, myUid, 3),
                          isCurrentTurn: matchState.currentTurnIndex == _getAbsoluteIndex(matchState, myUid, 3),
                          turnStartTime: matchState.turnStartTime,
                          timerDurationSeconds: matchState.timerDurationSeconds,
                          activeEmoji: _getPlayerEmoji(matchState, myUid, 3),
                          activeMessage: ref.watch(lastMessageForUserProvider(matchState.playerIds.isEmpty ? '' : matchState.playerIds[(_getAbsoluteIndex(matchState, myUid, 3)) % matchState.playerIds.length]))?.text,
                          teamColor: _getTeamColorForOffset(matchState, myUid, 3),
                        ),
                      ),
                    ),

                    // Right Player (Offset 1 in Anticlockwise)
                    Align(
                      alignment: isLandscape ? const Alignment(0.95, 0.2) : const Alignment(0.95, -0.15),
                      child: GestureDetector(
                        onTap: () => _showPlayerProfile(context, ref, matchState, myUid, 1),
                        child: PlayerAvatar(
                          user: _getAvatarUser(ref, matchState, myUid, 1),
                          isCurrentTurn: matchState.currentTurnIndex == _getAbsoluteIndex(matchState, myUid, 1),
                          turnStartTime: matchState.turnStartTime,
                          timerDurationSeconds: matchState.timerDurationSeconds,
                          activeEmoji: _getPlayerEmoji(matchState, myUid, 1),
                          activeMessage: ref.watch(lastMessageForUserProvider(matchState.playerIds.isEmpty ? '' : matchState.playerIds[(_getAbsoluteIndex(matchState, myUid, 1)) % matchState.playerIds.length]))?.text,
                          teamColor: _getTeamColorForOffset(matchState, myUid, 1),
                        ),
                      ),
                    ),

                    // Harvest Piles
                    Positioned(
                      left: isLandscape ? 120 : 16,
                      top: isLandscape ? 70 : 160,
                      child: _buildTeamHarvestPiles(matchState, 'teamA', isMyTeam: _getTeamOfPlayer(myUid, matchState.playerIds) == 'teamA'),
                    ),
                    Positioned(
                      right: isLandscape ? 120 : 16,
                      top: isLandscape ? 70 : 160,
                      child: _buildTeamHarvestPiles(matchState, 'teamB', isMyTeam: _getTeamOfPlayer(myUid, matchState.playerIds) == 'teamB'),
                    ),

                    Positioned.fill(
                      child: _buildBoardCenter(context, ref, matchState, myUid, isLandscape, is3DActive: show3DHand),
                    ),

                    // Local Player (Bottom Left - more robust alignment)
                    Align(
                      alignment: isLandscape ? const Alignment(-0.85, 0.95) : const Alignment(-0.85, 0.95),
                      child: _buildLocalPlayerArea(context, ref, matchState, myUid),
                    ),

                    // Centered Hand Cards (Hidden if 3D Hand is active)
                    if (!isSpectator && !show3DHand && (matchState.handCards[myUid]?.length ?? 0) > 0)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.zero,
                          child: FannedHandWidget(
                            cards: matchState.handCards[myUid] ?? [],
                            isMyTurn: matchState.playerIds.isNotEmpty && 
                                     matchState.currentTurnIndex == _getAbsoluteIndex(matchState, myUid, 0),
                            onCardTap: (card, globalOrigin) {
                              HapticFeedback.lightImpact();
                              
                              final RenderBox? boardBox = _boardKey.currentContext?.findRenderObject() as RenderBox?;
                              Offset relativeOrigin = Offset.zero;
                              
                              if (boardBox != null && globalOrigin != Offset.zero) {
                                final localOffset = boardBox.globalToLocal(globalOrigin);
                                // Board center is (100, 100)
                                relativeOrigin = Offset(localOffset.dx - 100, localOffset.dy - 100);
                              }
                              
                              ref.read(matchStateProvider.notifier).playCard(myUid, card, origin: relativeOrigin);
                            },
                          ),
                        ),
                      ),

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
                      
                    Positioned(
                      left: 12,
                      top: isLandscape ? 60 : 70, // Below top bar
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white10),
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildSideButton(
                              ref: ref,
                              icon: Icons.chat_bubble_outline,
                              onTap: () {
                                ref.read(chatStateProvider.notifier).toggleOverlay();
                              },
                              showBadge: true,
                            ),
                            const SizedBox(height: 16),
                            _buildSideButton(
                              ref: ref,
                              icon: Icons.emoji_emotions_outlined,
                              color: ThemeConfig.goldAccent,
                              onTap: () {
                                setState(() {
                                  _isEmoteWheelOpen = !_isEmoteWheelOpen;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildSideButton(
                              ref: ref,
                              icon: Icons.settings_outlined,
                              onTap: () {
                                _showSettings(context);
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildSideButton(
                              ref: ref,
                              icon: Icons.logout_rounded,
                              onTap: () => _confirmLeave(context, ref),
                              color: Colors.redAccent.withOpacity(0.8),
                            ),
                            const SizedBox(height: 16),
                            _buildSideButton(
                              ref: ref,
                              icon: Icons.bug_report_outlined,
                              onTap: () {
                                ref.read(unityCommunicationServiceProvider).postMessage(
                                  'UnityBridge',
                                  'ToggleConsole',
                                  '',
                                );
                              },
                              color: Colors.white24,
                            ),
                          ],
                        ),
                      ),
                    ),
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

  Widget _buildSideButton({
    required WidgetRef ref, 
    required IconData icon, 
    required VoidCallback onTap, 
    bool showBadge = false,
    Color? color,
  }) {
    final unreadCount = ref.watch(unreadMessagesCountProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(icon, color: color ?? Colors.white, size: 24),
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
        ),
        if (showBadge && unreadCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: ThemeConfig.accentPink, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScoreBadge(MatchState matchState) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              matchState.teamAScore.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 16, 
                color: ThemeConfig.primaryTeal,
                shadows: [Shadow(color: ThemeConfig.primaryTeal, blurRadius: 8)],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(':', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            ),
            Text(
              matchState.teamBScore.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 16, 
                color: ThemeConfig.goldAccent,
                shadows: [Shadow(color: ThemeConfig.goldAccent, blurRadius: 8)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpectatorCountBadge(int count) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility_outlined, color: ThemeConfig.goldAccent, size: 16),
            const SizedBox(width: 6),
            Text(
              count.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 14, 
                color: Colors.white,
              ),
            ),
          ],
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

  Widget _buildLocalPlayerArea(BuildContext context, WidgetRef ref, MatchState matchState, String myUid) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start, // Align to start (left) for better control with Positioned
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Avatar & Reactions
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _showPlayerProfile(context, ref, matchState, myUid, 0),
                    child: PlayerAvatar(
                      user: _getAvatarUser(ref, matchState, myUid, 0),
                      isCurrentTurn: matchState.playerIds.isNotEmpty && matchState.currentTurnIndex == _getAbsoluteIndex(matchState, myUid, 0),
                      turnStartTime: matchState.turnStartTime,
                      timerDurationSeconds: matchState.timerDurationSeconds,
                      activeEmoji: matchState.playerEmojis[myUid],
                      activeMessage: ref.watch(lastMessageForUserProvider(myUid))?.text,
                      teamColor: _getTeamColorForOffset(matchState, myUid, 0),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildReactionBar(ref, myUid),
                ],
              ),
              const SizedBox(width: 24),
              // Hand moved to bottom center of stack for better symmetry
            ],
          ),
        ],
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

  Widget _buildReactionBar(WidgetRef ref, String myUid) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: ['😂', '😡', '🤔', '😎'].map((e) => GestureDetector(
        onTap: () {
          ref.read(matchStateProvider.notifier).sendEmoji(myUid, e);
          Future.delayed(const Duration(seconds: 3), () {
            ref.read(matchStateProvider.notifier).clearEmoji(myUid);
          });
        },
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black26,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white10),
          ),
          child: Text(e, style: const TextStyle(fontSize: 16)),
        ),
      )).toList(),
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
  Widget _buildTopBar(BuildContext context, WidgetRef ref, MatchState matchState, bool isLandscape) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: App Name & Room ID
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: matchState.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('room_id_copied'.tr()),
                    backgroundColor: ThemeConfig.primaryTeal,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'app_title'.tr().toUpperCase(),
                    style: const TextStyle(
                      fontFamily: ThemeConfig.fontHeading,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 2,
                      color: ThemeConfig.primaryTeal,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.hub_outlined, color: Colors.white.withOpacity(0.5), size: 10),
                      const SizedBox(width: 4),
                      Text(
                        matchState.id,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.8),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Center: Score & Status
            _buildScoreBadge(matchState),
            
            // Right: Spectators & Match Status
            Row(
              children: [
                if (matchState.spectatorCount > 0)
                  _buildSpectatorCountBadge(matchState.spectatorCount),
                const SizedBox(width: 12),
                if (matchState.phase != GamePhase.waitingForPlayers)
                  _buildFloatingMatchStatusSmall(matchState),
              ],
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

