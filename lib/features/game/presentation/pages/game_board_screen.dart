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
import 'package:halabessa/features/game/presentation/providers/chat_providers.dart';
import 'package:halabessa/features/game/presentation/widgets/chat_overlay.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/services.dart';

class GameBoardScreen extends ConsumerStatefulWidget {
  const GameBoardScreen({super.key});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
  }

  @override
  void dispose() {
    _confettiController.dispose();
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
     
     return AppUser(uid: targetUid, email: '', displayName: targetName);
  }

  Widget _buildTeamHarvestStack(MatchState matchState, String teamId, {required bool isMyTeam}) {
    final captures = matchState.harvestStacks[teamId] ?? [];
    if (captures.isEmpty) return const SizedBox.shrink();

    // Alignment logic: Team A typically bottom/left-ish, Team B top/right-ish or vice versa.
    final alignment = teamId == 'teamA' ? const Alignment(-0.85, 0.45) : const Alignment(0.85, -0.45);

    return Align(
      alignment: alignment,
      child: HarvestStackWidget(captures: captures, teamName: isMyTeam ? 'my_team'.tr() : 'opponent_team'.tr()),
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('app_title'.tr(), 
              style: const TextStyle(fontFamily: ThemeConfig.fontHeading, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white)
            ),
            Text(
              'room_id_label'.tr(args: [matchState.id]),
              style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
        actions: [
          _buildScoreBadge(matchState),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70), 
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Table Top Background (Premium Skin)
          Positioned.fill(
            child: Consumer(
              builder: (context, ref, child) {
                final store = ref.watch(storeProvider);
                final notifier = ref.watch(storeProvider.notifier);
                final activeTable = notifier.allItems.firstWhere((i) => i.id == store.activeTableSkinId, orElse: () => notifier.allItems[3]);
                return activeTable.assetPath.startsWith('http')
                  ? Image.network(
                      activeTable.assetPath,
                      fit: BoxFit.cover,
                    )
                  : Image.asset(
                      activeTable.assetPath,
                      fit: BoxFit.cover,
                    );
              },
            ),
          ),
          // Additional Radial Overlay for Depth
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
                // Opponent (Top Center, Offset 2)
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16.0),
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

                // Left Player (Offset 3 in Anticlockwise)
                Align(
                  alignment: const Alignment(-0.95, -0.1),
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

                // Right Player (Offset 1 in Anticlockwise)
                Align(
                  alignment: const Alignment(0.95, -0.1),
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

                // Harvest Stacks & Board Center
                _buildTeamHarvestStack(matchState, 'teamA', isMyTeam: _getTeamOfPlayer(myUid, matchState.playerIds) == 'teamA'),
                _buildTeamHarvestStack(matchState, 'teamB', isMyTeam: _getTeamOfPlayer(myUid, matchState.playerIds) == 'teamB'),
                Center(child: _buildBoardCenter(context, ref, matchState, myUid)),

                // Local Player (Bottom Center)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildLocalPlayerArea(context, ref, matchState, myUid),
                ),

                // Phase Overlays
                if (matchState.phase == GamePhase.waitingForPlayers) _buildLobbyOverlay(context, ref, matchState, myUid),
                if (matchState.phase == GamePhase.preRoundCut) _buildCutOverlay(context, ref, matchState, myUid),
                if (matchState.phase == GamePhase.dealingFasha && matchState.cutLastCard != null) 
                   _buildLastCardReveal(matchState.cutLastCard!),
                if (matchState.phase == GamePhase.dealingFasha && matchState.cutLastCard == null) _buildPhaseOverlay('dealing_cards'.tr()),
                if (matchState.phase == GamePhase.dealingCards) _buildPhaseOverlay('memorize_fasha'.tr(args: ['5']), alignment: const Alignment(0, -0.4)),
                if (matchState.phase == GamePhase.shuffleVoting) _buildShuffleVoteOverlay(context, ref, matchState, myUid),
                if (matchState.phase == GamePhase.roundScoring) _buildContextualScoringOverlay(matchState, myUid),
                if (matchState.phase == GamePhase.rematchVoting) _buildRematchVoteOverlay(context, ref, matchState, myUid),
                if (matchState.phase == GamePhase.matchOver) _buildContextualGameOverOverlay(matchState, myUid),
                  
                // Chat Toggle (Left Edge)
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSideButton(
                            ref: ref,
                            icon: Icons.chat_bubble_outline,
                            onTap: () => ref.read(chatStateProvider.notifier).toggleOverlay(),
                            showBadge: true,
                          ),
                          const SizedBox(height: 16),
                          _buildSideButton(
                            ref: ref,
                            icon: Icons.settings_outlined,
                            onTap: () => _showSettings(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Chat Panel
          const ChatOverlay(),

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

  Widget _buildSideButton({required WidgetRef ref, required IconData icon, required VoidCallback onTap, bool showBadge = false}) {
    final unreadCount = ref.watch(unreadMessagesCountProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white, size: 28),
          onPressed: onTap,
        ),
        if (showBadge && unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
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
               Navigator.pop(context);
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

  Widget _buildBoardCenter(BuildContext context, WidgetRef ref, MatchState matchState, String myUid) {
    final size = MediaQuery.sizeOf(context);
    final isCapturing = matchState.phase == GamePhase.capturing;

    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: matchState.board.asMap().entries.map((entry) {
          final index = entry.key;
          final card = entry.value;
          
          final seed = card.suit.index * 13 + card.rank.index + index;
          final random = Random(seed);
          
          double targetX = (random.nextDouble() - 0.5) * 45;
          double targetY = (random.nextDouble() - 0.5) * 45;
          double rotation = (random.nextDouble() - 0.5) * 0.4;
          double scale = 1.0;

          // Animation Logic for Capturing
          if (isCapturing && matchState.capturingCards.any((c) => c.firebaseKey == card.firebaseKey)) {
            if (matchState.capturingStage == 0) {
              // stage 0: Symmetric Merge
              targetX = 0;
              targetY = 0;
              rotation = 0;
              scale = 1.25;
            } else {
              // stage 1: Fly to Harvest Box
              final teamId = matchState.capturingTeam;
              if (teamId == 'teamA') {
                targetX = -size.width * 0.35;
                targetY = size.height * 0.35;
              } else {
                targetX = size.width * 0.35;
                targetY = -size.height * 0.35;
              }
              rotation = 1.5; // Tumble while flying
              scale = 0.5; // Shrink as it goes to the box
            }
          } else if (matchState.phase == GamePhase.dealingCards) {
            targetX = (index - 1.5) * 70; 
            targetY = 0;
            rotation = 0;
          }
          
          String? ownerId = matchState.cardOwnership[card.firebaseKey];
          final effectiveOwnerId = ownerId ?? ((matchState.phase == GamePhase.dealingFasha || matchState.phase == GamePhase.dealingCards) && matchState.playerIds.isNotEmpty
              ? matchState.playerIds[matchState.dealerIndex % matchState.playerIds.length] 
              : null);

          // Default fallback: Fly from bottom
          double startX = 0;
          double startY = 350;

          if (effectiveOwnerId != null) {
            final myIdx = matchState.playerIds.indexOf(myUid);
            final pivotIdx = myIdx == -1 ? 0 : myIdx; // Spectators see from Host viewpoint
            final ownerIdx = matchState.playerIds.indexOf(effectiveOwnerId);

            if (ownerIdx >= 0) {
              final relativeIdx = (ownerIdx - pivotIdx + 4) % 4;
              if (relativeIdx == 1) { 
                startX = 320; startY = 0; // Right Avatar
              } else if (relativeIdx == 2) { 
                startX = 0; startY = -320; // Top Avatar (Opposite/Partner)
              } else if (relativeIdx == 3) { 
                startX = -320; startY = 0; // Left Avatar
              } else if (relativeIdx == 0) { 
                // Local player (or Host in spectator view): Check for specific click origin
                final localOrigins = ref.read(localPlayOriginsProvider);
                final customOrigin = localOrigins[card.firebaseKey];
                if (customOrigin != null) {
                  // Coordinate translation: Hand is shifted relative to avatar.
                  startX = customOrigin.dx + 48; // Dynamic hand offset
                  startY = customOrigin.dy + 280; // Distance to hand
                } else {
                  startX = 0; 
                  startY = 350; // Standard bottom fly-in
                }
              }
            }
          }

          return TweenAnimationBuilder<double>(
            key: ValueKey(card.firebaseKey),
            duration: Duration(milliseconds: isCapturing ? 800 : 500),
            curve: isCapturing ? Curves.easeInOutBack : Curves.easeOutCubic,
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              final currentX = startX * (1 - value) + targetX * value;
              final currentY = startY * (1 - value) + targetY * value;
              
              // Smoother transition: If from hand (origin != null), start slightly larger (1.1).
              // Otherwise (dealing/opponents), standard scaling.
              final startScale = (startX != 0 || startY != 350) ? 1.1 : 1.0;
              final currentScale = (startScale - (startScale - 1.0) * value) * (isCapturing ? scale : 1.0);

              return Transform.translate(
                offset: Offset(currentX, currentY),
                child: Transform.rotate(
                  angle: rotation * value,
                  child: Transform.scale(
                    scale: currentScale,
                    child: child,
                  ),
                ),
              );
            },
            child: CardWidget(card: card),
          );
        }).toList(),
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
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Avatar & Reactions
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlayerAvatar(
                    user: _getAvatarUser(ref, matchState, myUid, 0),
                    isCurrentTurn: matchState.playerIds.isNotEmpty && matchState.currentTurnIndex == _getAbsoluteIndex(matchState, myUid, 0),
                    turnStartTime: matchState.turnStartTime,
                    timerDurationSeconds: matchState.timerDurationSeconds,
                    activeEmoji: matchState.playerEmojis[myUid],
                    activeMessage: ref.watch(lastMessageForUserProvider(myUid))?.text,
                    teamColor: _getTeamColorForOffset(matchState, myUid, 0),
                  ),
                  const SizedBox(height: 8),
                  _buildReactionBar(ref, myUid),
                ],
              ),
              const SizedBox(width: 24),
              // Hand
              if ((matchState.handCards[myUid]?.length ?? 0) > 0)
                FannedHandWidget(
                  cards: matchState.handCards[myUid] ?? [],
                  isMyTurn: matchState.playerIds.isNotEmpty && 
                           matchState.currentTurnIndex == _getAbsoluteIndex(matchState, myUid, 0),
                  onCardTap: (card, origin) {
                    HapticFeedback.lightImpact();
                    ref.read(matchStateProvider.notifier).playCard(myUid, card, origin: origin);
                  },
                ),
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
    final myTeamId = _getTeamOfPlayer(myUid, matchState.playerIds);
    final myScore = myTeamId == 'teamA' ? matchState.teamAScore : matchState.teamBScore;
    final oppScore = myTeamId == 'teamA' ? matchState.teamBScore : matchState.teamAScore;
    return _buildPhaseOverlay('round_scoring'.tr(args: [myScore.toString(), oppScore.toString()]), alignment: Alignment.center);
  }

  Widget _buildContextualGameOverOverlay(MatchState matchState, String myUid) {
    final myTeamId = _getTeamOfPlayer(myUid, matchState.playerIds);
    final myScore = myTeamId == 'teamA' ? matchState.teamAScore : matchState.teamBScore;
    final oppScore = myTeamId == 'teamA' ? matchState.teamBScore : matchState.teamAScore;
    return _buildPhaseOverlay('match_over'.tr(args: [myScore.toString(), oppScore.toString()]));
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
    final humanCount = state.playerIds.where((id) => !id.startsWith('waiting_')).toList().length;
    
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
            Text('waiting_for_players'.tr(), 
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
                            onPressed: () {
                              ref.read(multiplayerSyncServiceProvider).sendInvite(friendId, state.id, currentUser.displayName);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('invitation_sent'.tr())));
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
}

class HarvestStackWidget extends StatelessWidget {
  final List<Capture> captures;
  final String teamName;

  const HarvestStackWidget({super.key, required this.captures, required this.teamName});

  @override
  Widget build(BuildContext context) {
    int totalCards = captures.fold(0, (sum, cap) => sum + cap.capturedCards.length + 1);
    
    return GestureDetector(
      onTap: () => _showHarvestDetails(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12, width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, color: ThemeConfig.goldAccent, size: 16),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(teamName, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                Text('total_cards_count'.tr(args: [totalCards.toString()]), 
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9)),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.open_in_full, color: Colors.white24, size: 12),
          ],
        ),
      ),
    );
  }

  void _showHarvestDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => HarvestDetailsOverlay(captures: captures, teamName: teamName),
    );
  }
}

class HarvestDetailsOverlay extends StatelessWidget {
  final List<Capture> captures;
  final String teamName;

  const HarvestDetailsOverlay({super.key, required this.captures, required this.teamName});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: ThemeConfig.goldAccent),
                const SizedBox(width: 12),
                Text(
                  'harvest_details'.tr(args: [teamName]),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: ThemeConfig.fontHeading),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: captures.isEmpty
                ? Center(child: Text('no_captures_yet'.tr(), style: const TextStyle(color: Colors.white38)))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: captures.length,
                    itemBuilder: (context, index) {
                      final cap = captures[index];
                      return Column(
                        children: [
                          Expanded(child: CardWidget(card: cap.leadingCard)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              '+${cap.capturedCards.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
