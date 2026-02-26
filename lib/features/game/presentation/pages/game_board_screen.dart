import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/game/presentation/widgets/card_widget.dart';
import 'package:halabessa/features/game/presentation/widgets/player_avatar.dart';
import 'package:halabessa/features/game/presentation/widgets/fanned_hand_widget.dart';
import 'package:halabessa/features/game/domain/models/capture.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/core/widgets/settings_overlay.dart';
import 'package:halabessa/features/home/presentation/providers/store_provider.dart';

class GameBoardScreen extends ConsumerWidget {
  const GameBoardScreen({super.key});

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
     String targetName = matchState.playerNames[targetUid] ?? (targetUid.startsWith('bot_') ? 'bot_name'.tr() : 'player_default_name'.tr());
     
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
    if (myIdx == -1) return offset;
    return (myIdx + offset) % 4;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchState = ref.watch(matchStateProvider);
    final currentUser = ref.watch(currentUserProvider);

    if (matchState == null || currentUser == null) {
      if (currentUser != null && matchState == null) {
        Future.microtask(() => ref.read(matchStateProvider.notifier).tryRecoverLastMatch());
      }

      return Scaffold(
        backgroundColor: ThemeConfig.darkBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(ThemeConfig.goldAccent),
              ),
              const SizedBox(height: 32),
              Text(
                'loading_match_environment'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 48),
              _buildRetryButton(context, ref),
            ],
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
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const SettingsOverlay(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Table Top Background (Premium Skin)
          Positioned.fill(
            child: Consumer(
              builder: (context, ref, child) {
                final activeTable = ref.watch(storeProvider.notifier).activeTableSkin;
                return Image.asset(
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
                    ),
                  ),
                ),

                // Left Player (Offset 1)
                Align(
                  alignment: const Alignment(-0.95, -0.1),
                  child: PlayerAvatar(
                    user: _getAvatarUser(ref, matchState, myUid, 1),
                    isCurrentTurn: matchState.currentTurnIndex == _getAbsoluteIndex(matchState, myUid, 1),
                    turnStartTime: matchState.turnStartTime,
                    timerDurationSeconds: matchState.timerDurationSeconds,
                    activeEmoji: _getPlayerEmoji(matchState, myUid, 1),
                  ),
                ),

                // Right Player (Offset 3)
                Align(
                  alignment: const Alignment(0.95, -0.1),
                  child: PlayerAvatar(
                    user: _getAvatarUser(ref, matchState, myUid, 3),
                    isCurrentTurn: matchState.currentTurnIndex == _getAbsoluteIndex(matchState, myUid, 3),
                    turnStartTime: matchState.turnStartTime,
                    timerDurationSeconds: matchState.timerDurationSeconds,
                    activeEmoji: _getPlayerEmoji(matchState, myUid, 3),
                  ),
                ),

                // Harvest Stacks
                _buildTeamHarvestStack(matchState, 'teamA', isMyTeam: _getTeamOfPlayer(myUid, matchState.playerIds) == 'teamA'),
                _buildTeamHarvestStack(matchState, 'teamB', isMyTeam: _getTeamOfPlayer(myUid, matchState.playerIds) == 'teamB'),

                // Center Area (Harvest Stacks & Played Cards)
                Center(
                  child: _buildBoardCenter(context, ref, matchState, myUid),
                ),

                // Local Player (Bottom Center, Offset 0)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildLocalPlayerArea(context, ref, matchState, myUid),
                ),

                // Phase indicator overlay
                if (matchState.phase == GamePhase.waitingForPlayers)
                  _buildLobbyOverlay(context, ref, matchState, myUid),
                if (matchState.phase == GamePhase.preRoundCut)
                  _buildCutOverlay(context, ref, matchState, myUid),
                 if (matchState.phase == GamePhase.dealingFasha)
                   _buildPhaseOverlay('dealing_cards'.tr()),
                  if (matchState.phase == GamePhase.dealingCards)
                    _buildPhaseOverlay('memorize_fasha'.tr(args: ['5']), alignment: const Alignment(0, -0.4)),
                 if (matchState.phase == GamePhase.shuffleVoting)
                   _buildShuffleVoteOverlay(context, ref, matchState, myUid),
                if (matchState.phase == GamePhase.roundScoring)
                   _buildContextualScoringOverlay(matchState, myUid),
                 if (matchState.phase == GamePhase.rematchVoting)
                   _buildRematchVoteOverlay(context, ref, matchState, myUid),
                 if (matchState.phase == GamePhase.matchOver)
                   _buildContextualGameOverOverlay(matchState, myUid),
              ],
            ),
          ),
        ],
      ),
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
        child: Text(
          'score'.tr(args: [matchState.teamAScore.toString(), matchState.teamBScore.toString()]), 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber)
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
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black26,
          foregroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: const BorderSide(color: Colors.white10),
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
        child: Text('retry_or_exit'.tr()),
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

          if (matchState.phase == GamePhase.dealingCards) {
            targetX = (index - 1.5) * 70; 
            targetY = 0;
            rotation = 0;
          }
          
          String? ownerId = matchState.cardOwnership[card.firebaseKey];
          double startX = 0;
          double startY = 400;
          
          final effectiveOwnerId = ownerId ?? ((matchState.phase == GamePhase.dealingFasha || matchState.phase == GamePhase.dealingCards) && matchState.playerIds.isNotEmpty
              ? matchState.playerIds[matchState.dealerIndex % matchState.playerIds.length] 
              : null);

          if (effectiveOwnerId != null) {
            int myIdx = matchState.playerIds.indexOf(myUid);
            int ownerIdx = matchState.playerIds.indexOf(effectiveOwnerId);
            if (myIdx != -1 && ownerIdx != -1) {
              int relativeIdx = (ownerIdx - myIdx + 4) % 4;
              if (relativeIdx == 1) { startX = -400; startY = 0; }
              else if (relativeIdx == 2) { startX = 0; startY = -400; }
              else if (relativeIdx == 3) { startX = 400; startY = 0; }
              else if (relativeIdx == 0) { startX = 0; startY = 400; }
            }
          }

          return TweenAnimationBuilder<double>(
            key: ValueKey(card.firebaseKey),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              final currentX = startX * (1 - value) + targetX * value;
              final currentY = startY * (1 - value) + targetY * value;
              
              return Transform.translate(
                offset: Offset(currentX, currentY),
                child: Transform.rotate(
                  angle: rotation * value,
                  child: Transform.scale(
                    scale: 0.8 + 0.2 * value,
                    child: child,
                  ),
                ),
              );
            },
            child: Consumer(
              builder: (context, ref, child) {
                final activeCard = ref.watch(storeProvider.notifier).activeCardBack;
                return CardWidget(
                  card: card, 
                  customBackPath: activeCard.assetPath,
                  customFrontPath: activeCard.frontSkinPath,
                  faceIllustrations: activeCard.faceIllustrations,
                );
              },
            ),
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
                  onCardTap: (card) {
                    ref.read(matchStateProvider.notifier).playCard(myUid, card);
                  },
                ),
            ],
          ),
        ],
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
    final totalPlayers = state.playerIds.length;
    
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
                    child: Icon(Icons.person, size: 14, color: id == currentUid ? Colors.white : Colors.white38),
                  ),
                  const SizedBox(width: 12),
                  Text(id == currentUid ? "you".tr() : (state.playerNames[id] ?? "player_default_name".tr()), 
                    style: TextStyle(color: id == currentUid ? Colors.green : Colors.white)
                  ),
                  const Spacer(),
                  if (state.botInjectionVotes.containsKey(id))
                    const Icon(Icons.check_circle, color: Colors.green, size: 18),
                ],
              ),
            )),
            const SizedBox(height: 32),
            if (totalPlayers < 4) ...[
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
                Text('waiting_human_consent'.tr(args: [readyCount.toString(), totalPlayers.toString()]), 
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

class HarvestStackWidget extends StatefulWidget {
  final List<Capture> captures;
  final String teamName;

  const HarvestStackWidget({super.key, required this.captures, required this.teamName});

  @override
  State<HarvestStackWidget> createState() => _HarvestStackWidgetState();
}

class _HarvestStackWidgetState extends State<HarvestStackWidget> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => isExpanded = !isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12, width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: ThemeConfig.goldAccent, size: 14),
                const SizedBox(width: 4),
                Text(widget.teamName, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const Spacer(),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white38, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            if (!isExpanded)
              _buildCompactView()
            else
              _buildExpandedView(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactView() {
    if (widget.captures.isEmpty) return const SizedBox.shrink();
    final lastCapture = widget.captures.last;
    return SizedBox(
      height: 90,
      child: Stack(
        children: [
          ...List.generate(min(3, lastCapture.capturedCards.length + 2), (idx) => Positioned(
            left: idx * 4.0,
            top: idx * 2.0,
            child: Container(
              width: 55,
              height: 75,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white10, width: 1),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
              ),
              child: Consumer(
                builder: (context, ref, _) {
                  final activeCard = ref.watch(storeProvider.notifier).activeCardBack;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(activeCard.assetPath, fit: BoxFit.cover),
                  );
                },
              ),
            ),
          )),
          Positioned(
            left: 12,
            top: 6,
            child: Transform.rotate(
              angle: 0.05,
              child: SizedBox(
                width: 55,
                height: 75,
                child: CardWidget(card: lastCapture.leadingCard),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedView() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.captures.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final cap = widget.captures[index];
          return Column(
            children: [
              SizedBox(
                width: 50,
                height: 70,
                child: CardWidget(card: cap.leadingCard),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                child: Text('+${cap.capturedCards.length}', style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ],
          );
        },
      ),
    );
  }
}
