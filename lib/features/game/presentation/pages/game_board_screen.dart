import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../domain/providers/game_providers.dart';
import '../../domain/models/match_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/models/app_user.dart';
import '../widgets/card_widget.dart';
import '../widgets/player_avatar.dart';

class GameBoardScreen extends ConsumerWidget {
  const GameBoardScreen({super.key});

  AppUser _getAvatarUser(WidgetRef ref, MatchState matchState, String currentUserUid, int relativeOffset) {
     int myIdx = matchState.playerIds.indexOf(currentUserUid);
     if (myIdx == -1) return AppUser(uid: 'spectator', email: '', displayName: 'Spectator');
     
     // 0 = Bottom (Local Player), 1 = Left, 2 = Top (Opponent), 3 = Right
     if (relativeOffset == 0) {
        final realUser = ref.watch(currentUserProvider)!;
        return realUser.copyWith(displayName: 'You (${realUser.displayName})');
     }
     
     int targetIdx = (myIdx + relativeOffset) % 4;
     if (targetIdx >= matchState.playerIds.length) return AppUser(uid: 'empty', email: '', displayName: 'Waiting...');
     
     String targetUid = matchState.playerIds[targetIdx];
     
     if (targetUid.startsWith('bot_')) {
        return AppUser(uid: targetUid, email: '', displayName: '🤖 Bot ${targetUid.split('_')[1]}');
     }
     
     String positionName = relativeOffset == 1 ? "Left Player" : relativeOffset == 2 ? "Opponent" : "Right Player";
     return AppUser(uid: targetUid, email: '', displayName: positionName);
  }

  int _getAbsoluteIndex(MatchState matchState, String currentUserUid, int relativeOffset) {
     int myIdx = matchState.playerIds.indexOf(currentUserUid);
     if (myIdx == -1) return -1;
     return (myIdx + relativeOffset) % 4;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchState = ref.watch(matchStateProvider);
    final currentUser = ref.watch(currentUserProvider);

    if (matchState == null || currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Loading Match Environment...")),
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
               child: Text('score'.tr(args: [matchState.teamAScore.toString(), matchState.teamBScore.toString()]), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
             ),
          ),
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Table Top Background
            Container(
              decoration: BoxDecoration(color: Colors.green.shade800),
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
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: PlayerAvatar(
                   user: _getAvatarUser(ref, matchState, myUid, 1),
                   isCurrentTurn: matchState.currentTurnIndex == _getAbsoluteIndex(matchState, myUid, 1),
                   turnStartTime: matchState.turnStartTime,
                   timerDurationSeconds: matchState.timerDurationSeconds,
                   activeEmoji: matchState.playerIds.length > _getAbsoluteIndex(matchState, myUid, 1) ? matchState.playerEmojis[matchState.playerIds[_getAbsoluteIndex(matchState, myUid, 1)]] : null,
                ),
              ),
            ),

            // Right Player (Offset 3)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: PlayerAvatar(
                   user: _getAvatarUser(ref, matchState, myUid, 3),
                   isCurrentTurn: matchState.currentTurnIndex == _getAbsoluteIndex(matchState, myUid, 3),
                   turnStartTime: matchState.turnStartTime,
                   timerDurationSeconds: matchState.timerDurationSeconds,
                   activeEmoji: matchState.playerIds.length > _getAbsoluteIndex(matchState, myUid, 3) ? matchState.playerEmojis[matchState.playerIds[_getAbsoluteIndex(matchState, myUid, 3)]] : null,
                ),
              ),
            ),

            // The Board (Fasha / Center Stack)
            Center(
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.center,
                children: matchState.board.map((card) => CardWidget(card: card)).toList(),
              ),
            ),
            
            // Local Player (Bottom Center, Offset 0)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reaction Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: ['😂', '😡', '🤔', '😎'].map((e) => GestureDetector(
                        onTap: () {
                           ref.read(matchStateProvider.notifier).sendEmoji(myUid, e);
                           Future.delayed(const Duration(seconds: 3), () {
                              ref.read(matchStateProvider.notifier).clearEmoji(myUid);
                           });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(e, style: const TextStyle(fontSize: 24)),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 8),
                     PlayerAvatar(
                       user: _getAvatarUser(ref, matchState, myUid, 0),
                       isCurrentTurn: matchState.playerIds.isNotEmpty && matchState.currentTurnIndex == _getAbsoluteIndex(matchState, myUid, 0),
                       turnStartTime: matchState.turnStartTime,
                       timerDurationSeconds: matchState.timerDurationSeconds,
                       activeEmoji: matchState.playerEmojis[myUid],
                    ),
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
                            return CardWidget(
                              card: card,
                              onTap: () {
                                 ref.read(matchStateProvider.notifier).playCard(myUid, card);
                              },
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
                Text('Room ID: ${state.id}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.w500)),
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
                         Text(id == currentUid ? "you".tr() : "player_uuid".tr(args: [id.substring(0, 5)]), style: TextStyle(color: id == currentUid ? Colors.green : Colors.white)),
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
