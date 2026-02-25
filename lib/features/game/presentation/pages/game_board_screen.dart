import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../domain/providers/game_providers.dart';
import '../../domain/models/match_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/models/app_user.dart';
import '../widgets/card_widget.dart';
import '../widgets/player_avatar.dart';
import '../../domain/models/capture.dart';
import '../../../../core/theme/theme_config.dart';

class GameBoardScreen extends ConsumerWidget {
  const GameBoardScreen({super.key});

  AppUser _getAvatarUser(WidgetRef ref, MatchState matchState, String currentUserUid, int relativeOffset) {
     int myIdx = matchState.playerIds.indexOf(currentUserUid);
     
     // spectator logic: if I'm not in the playerIds, I see from Host's perspective (bottom = T1P1)
     int baseIdx = myIdx == -1 ? 0 : myIdx;
     
     // 0 = Bottom (Local Player), 1 = Left, 2 = Top (Opponent), 3 = Right
     if (myIdx != -1 && relativeOffset == 0) {
        final realUser = ref.watch(currentUserProvider)!;
        return realUser.copyWith(displayName: 'You (${realUser.displayName})');
     }
     
     int targetIdx = (baseIdx + relativeOffset) % 4;
     if (targetIdx >= matchState.playerIds.length) return AppUser(uid: 'empty', email: '', displayName: 'Waiting...');
     
     String targetUid = matchState.playerIds[targetIdx];
     String targetName = matchState.playerNames[targetUid] ?? (targetUid.startsWith('bot_') ? '🤖 Bot' : 'Player');
     
     return AppUser(uid: targetUid, email: '', displayName: targetName);
  }

  Widget _buildTeamHarvestStack(MatchState matchState, String teamId, {required bool isMyTeam}) {
    final captures = matchState.harvestStacks[teamId] ?? [];
    if (captures.isEmpty) return const SizedBox.shrink();

    // Alignment logic: Team A typically bottom/left-ish, Team B top/right-ish or vice versa.
    // For now, let's put Team A harvest bottom-left and Team B harvest top-right.
    final alignment = teamId == 'teamA' ? const Alignment(-0.85, 0.7) : const Alignment(0.85, -0.7);

    return Align(
      alignment: alignment,
      child: HarvestStackWidget(captures: captures, teamName: teamId.replaceAll('team', 'Team ')),
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
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text('loading_match_environment'.tr()),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                   final lastId = ref.read(matchStateProvider.notifier).lastBoundMatchId;
                   if (lastId != null) {
                      ref.read(matchStateProvider.notifier).rebind(lastId);
                   } else {
                      Navigator.pop(context);
                   }
                },
                child: Text('retry_or_exit'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    final myUid = currentUser.uid;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('7alabessa Match'),
            Text(
              'Room ID: ${matchState.id}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Center(
             child: Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16.0),
               child: Text(
                 'score'.tr(args: [matchState.teamAScore.toString(), matchState.teamBScore.toString()]), 
                 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
               ),
             ),
          ),
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Table Top Background (Premium Radial Gradient)
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(0xFF2E7D32), // Lighter green center
                    Color(0xFF1B5E20), // Mid green
                    Color(0xFF0D3310), // Dark borders
                  ],
                  radius: 1.2,
                  center: Alignment.center,
                ),
              ),
            ),
            
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
                   activeEmoji: matchState.playerIds.length > _getAbsoluteIndex(matchState, myUid, 2) ? matchState.playerEmojis[matchState.playerIds[_getAbsoluteIndex(matchState, myUid, 2)]] : null,
                ),
              ),
            ),

            // Left Player (Offset 1)
            Align(
              alignment: const Alignment(-0.95, 0),
              child: PlayerAvatar(
                 user: _getAvatarUser(ref, matchState, myUid, 1),
                 isCurrentTurn: matchState.currentTurnIndex == _getAbsoluteIndex(matchState, myUid, 1),
                 turnStartTime: matchState.turnStartTime,
                 timerDurationSeconds: matchState.timerDurationSeconds,
                 activeEmoji: matchState.playerIds.length > _getAbsoluteIndex(matchState, myUid, 1) ? matchState.playerEmojis[matchState.playerIds[_getAbsoluteIndex(matchState, myUid, 1)]] : null,
              ),
            ),

            // Right Player (Offset 3)
            Align(
              alignment: const Alignment(0.95, 0),
              child: PlayerAvatar(
                 user: _getAvatarUser(ref, matchState, myUid, 3),
                 isCurrentTurn: matchState.currentTurnIndex == _getAbsoluteIndex(matchState, myUid, 3),
                 turnStartTime: matchState.turnStartTime,
                 timerDurationSeconds: matchState.timerDurationSeconds,
                 activeEmoji: matchState.playerIds.length > _getAbsoluteIndex(matchState, myUid, 3) ? matchState.playerEmojis[matchState.playerIds[_getAbsoluteIndex(matchState, myUid, 3)]] : null,
              ),
            ),

            // Team A Harvest Stack (Adjacent to Player 0 - typically Bottom/Self if Host)
            _buildTeamHarvestStack(matchState, 'teamA', isMyTeam: _getTeamOfPlayer(myUid, matchState.playerIds) == 'teamA'),

            // Team B Harvest Stack (Adjacent to Player 1 - typically Left)
            _buildTeamHarvestStack(matchState, 'teamB', isMyTeam: _getTeamOfPlayer(myUid, matchState.playerIds) == 'teamB'),

            // The Board (Fasha / Center Stack - Physical Pile)
            Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: matchState.board.asMap().entries.map((entry) {
                    final index = entry.key;
                    final card = entry.value;
                    
                    // Deterministic "randomness" based on card properties
                     final seed = card.suit.index * 13 + card.rank.index + index;
                     final random = Random(seed);
                     
                     final rotation = (random.nextDouble() - 0.5) * 0.4; // +/- 11 degrees
                     final offsetX = (random.nextDouble() - 0.5) * 45;
                     final offsetY = (random.nextDouble() - 0.5) * 45;
                     
                     // 1. Determine who played this card to set start position
                     String? ownerId = matchState.cardOwnership['${card.suit}_${card.rank}'];
                     double startX = 0;
                     double startY = 400; // Default: Bottom
                     
                     if (ownerId != null) {
                       int myIdx = matchState.playerIds.indexOf(myUid);
                       int ownerIdx = matchState.playerIds.indexOf(ownerId);
                       if (myIdx != -1 && ownerIdx != -1) {
                         int relativeIdx = (ownerIdx - myIdx + 4) % 4;
                         if (relativeIdx == 1) { startX = -400; startY = 0; } // Left
                         else if (relativeIdx == 2) { startX = 0; startY = -400; } // Top
                         else if (relativeIdx == 3) { startX = 400; startY = 0; } // Right
                       }
                     }

                     return TweenAnimationBuilder<double>(
                       duration: const Duration(milliseconds: 600),
                       curve: Curves.easeOutCubic,
                       tween: Tween(begin: 0.0, end: 1.0),
                       builder: (context, value, child) {
                         final currentX = startX * (1 - value) + offsetX * value;
                         final currentY = startY * (1 - value) + offsetY * value;
                         
                         return Transform.translate(
                           offset: Offset(currentX, currentY),
                           child: Transform.rotate(
                             angle: rotation * value,
                             child: Transform.scale(
                               scale: 0.4 + 0.6 * value,
                               child: child,
                             ),
                           ),
                         );
                       },
                       child: CardWidget(card: card),
                     );
                  }).toList(),
                ),
              ),
            ),
            
            // Local Player (Bottom Left to clear center)
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
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
                    // Reaction Bar (Small)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: ['😂', '😡', '🤔', '😎'].map((e) => GestureDetector(
                        onTap: () {
                           ref.read(matchStateProvider.notifier).sendEmoji(myUid, e);
                           Future.delayed(const Duration(seconds: 3), () {
                              ref.read(matchStateProvider.notifier).clearEmoji(myUid);
                           });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(e, style: const TextStyle(fontSize: 18)),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ),
            
            // Local Player's Hand (Bottom Center)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    if ((matchState.handCards[myUid]?.length ?? 0) > 0) ...[
                      const SizedBox(height: 16),
                      // Player Hand
                      SizedBox(
                        height: 120, // Enough height for the card
                        child: ListView.separated(
                          shrinkWrap: true,
                          scrollDirection: Axis.horizontal,
                          itemCount: matchState.handCards[myUid]!.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final card = matchState.handCards[myUid]![index];
                            return Hero(
                              tag: 'card_${card.suit.index}_${card.rank.index}',
                              child: CardWidget(
                                card: card,
                                onTap: () {
                                   ref.read(matchStateProvider.notifier).playCard(myUid, card);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Phase indicator overlay
             if (matchState.phase == GamePhase.waitingForPlayers)
               _buildLobbyOverlay(context, ref, matchState, myUid),
             if (matchState.phase == GamePhase.preRoundCut)
               _buildCutOverlay(context, ref, matchState, myUid),
             if (matchState.phase == GamePhase.dealingFasha)
               _buildPhaseOverlay('Memorize the Fasha! 5s...'),
             if (matchState.phase == GamePhase.shuffleVoting)
               _buildShuffleVoteOverlay(context, ref, matchState, myUid),
             if (matchState.phase == GamePhase.rematchVoting)
               _buildRematchVoteOverlay(context, ref, matchState, myUid),
             if (matchState.phase == GamePhase.matchOver)
               _buildPhaseOverlay('Match Finalized.'),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseOverlay(String text) {
     return Center(
       child: Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black87,
          child: Text(
            text, 
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
          ),
       ),
     );
  }

  Widget _buildCutOverlay(BuildContext context, WidgetRef ref, MatchState state, String currentUid) {
     int myIdx = state.playerIds.indexOf(currentUid);
     int cutterIdx = (state.dealerIndex + 3) % 4; // Right of dealer
     bool isMyCut = myIdx == cutterIdx;
     
     // Note: we'll show the cut button to everyone for testing/debug, but highlight whose turn it really is
     return Center(
       child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
          child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               const Text('pre_round_cut', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)).tr(),
               const SizedBox(height: 16),
               if (isMyCut) ...[
                  const Text('your_turn_cut_deck', style: TextStyle(color: Colors.white70)).tr(),
               ] else ...[
                  const Text('waiting_deck_cut', style: TextStyle(color: Colors.white70)).tr(),
               ],
               const SizedBox(height: 24),
               ElevatedButton(
                  onPressed: () => ref.read(matchStateProvider.notifier).performCut(20), // Placeholder random cut index
                  child: Text(isMyCut ? 'Cut Deck' : 'Cut Deck (Force)'),
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
           padding: const EdgeInsets.all(24),
           decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
           child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('waiting_for_players'.tr(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Room ID: ${state.id}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.person_add_alt_1, color: Colors.teal, size: 20),
                      onPressed: () => _showInviteFriendDialog(context, ref, state, currentUid),
                      tooltip: 'invite_friends'.tr(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('connected_players'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                ...state.playerIds.map((id) => Padding(
                   padding: const EdgeInsets.symmetric(vertical: 4.0),
                   child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         Icon(Icons.person, color: id == currentUid ? Colors.green : Colors.white54, size: 20),
                         const SizedBox(width: 8),
                         Text(id == currentUid ? "you".tr() : (state.playerNames[id] ?? "player_uuid".tr(args: [id.substring(0, 5)])), style: TextStyle(color: id == currentUid ? Colors.green : Colors.white)),
                         if (state.botInjectionVotes.containsKey(id))
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Icon(Icons.check_circle, color: Colors.green, size: 16),
                            ),
                      ],
                   ),
                )),
                const SizedBox(height: 24),
                if (totalPlayers < 4) ...[
                   if (!isReady)
                      ElevatedButton.icon(
                        onPressed: () => ref.read(matchStateProvider.notifier).voteForBots(currentUid),
                        icon: const Icon(Icons.smart_toy),
                        label: Text('ready_fill_bots'.tr()),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                      )
                   else
                      Text('waiting_human_consent'.tr(args: [readyCount.toString(), totalPlayers.toString()]), style: const TextStyle(color: Colors.orangeAccent, fontStyle: FontStyle.italic)),
                ] else
                   Text('room_full_starting'.tr(), style: const TextStyle(color: Colors.green)),
              ],
           ),
        ),
      );
   }

  Widget _buildShuffleVoteOverlay(BuildContext context, WidgetRef ref, MatchState state, String currentUid) {
     final hasVoted = state.shuffleVotes.containsKey(currentUid);
     return Center(
       child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
          child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               Text('deck_finished'.tr(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
               const SizedBox(height: 16),
               Text('shuffle_votes'.tr(args: [state.shuffleVotes.length.toString()]), style: const TextStyle(color: Colors.white70)),
               const SizedBox(height: 24),
               if (!hasVoted) Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   ElevatedButton(
                     onPressed: () => ref.read(matchStateProvider.notifier).voteShuffle(currentUid, true),
                     child: Text('shuffle_yes'.tr()),
                   ),
                   const SizedBox(width: 16),
                   ElevatedButton(
                     style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                     onPressed: () => ref.read(matchStateProvider.notifier).voteShuffle(currentUid, false),
                     child: Text('keep_sequence_no'.tr(), style: const TextStyle(color: Colors.white)),
                   ),
                 ],
               ) else Text('waiting_for_other_players'.tr(), style: const TextStyle(color: Colors.white)),
             ],
          ),
       ),
     );
  }

  Widget _buildRematchVoteOverlay(BuildContext context, WidgetRef ref, MatchState state, String currentUid) {
     final hasVoted = state.rematchVotes.containsKey(currentUid);
     final bool aWins = state.teamAScore >= state.teamBScore;
     return Center(
       child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
          child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               Text('match_over'.tr(), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
               Text('team_wins'.tr(args: [aWins ? "A" : "B"]), style: const TextStyle(color: Colors.greenAccent, fontSize: 20)),
               const SizedBox(height: 16),
               Text('rematch_votes'.tr(args: [state.rematchVotes.length.toString()]), style: const TextStyle(color: Colors.white70)),
               const SizedBox(height: 24),
               if (!hasVoted) Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   ElevatedButton(
                     onPressed: () => ref.read(matchStateProvider.notifier).voteRematch(currentUid, true),
                     child: Text('best_of_3_yes'.tr()),
                   ),
                   const SizedBox(width: 16),
                   ElevatedButton(
                     style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                     onPressed: () => ref.read(matchStateProvider.notifier).voteRematch(currentUid, false),
                     child: Text('leave_match_no'.tr(), style: const TextStyle(color: Colors.white)),
                   ),
                 ],
               ) else Text('waiting_for_other_players'.tr(), style: const TextStyle(color: Colors.white)),
             ],
          ),
       ),
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
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1),
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
                Text(widget.teamName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                const Spacer(),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white70, size: 16),
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
    final lastCapture = widget.captures.last;
    return SizedBox(
      height: 90,
      child: Stack(
        children: [
          // "Face-down" cards representing the bulk of the stack
          ...List.generate(min(3, lastCapture.capturedCards.length + 2), (idx) => Positioned(
            left: idx * 3.0,
            top: idx * 2.0,
            child: Container(
              width: 55,
              height: 75,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade900, Colors.blue.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white38, width: 1),
              ),
              child: const Center(child: Icon(Icons.style, color: Colors.white24, size: 20)),
            ),
          )),
          // Face-up leading card (The card that captured the stack)
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
