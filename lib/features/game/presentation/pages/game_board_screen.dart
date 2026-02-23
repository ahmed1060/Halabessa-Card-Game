import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers/game_providers.dart';
import '../../domain/models/match_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../widgets/card_widget.dart';
import '../widgets/player_avatar.dart';

class GameBoardScreen extends ConsumerWidget {
  const GameBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchState = ref.watch(matchStateProvider);
    final currentUser = ref.watch(currentUserProvider);

    if (matchState == null || currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Loading Match Environment...")),
      );
    }

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
               child: Text('Score: ${matchState.teamAScore} - ${matchState.teamBScore}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
            
            // Opponent (Top Center)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: PlayerAvatar(
                   user: currentUser, // Placeholder: Use actual opponent from matchState.playerIds
                   isCurrentTurn: matchState.currentTurnIndex == 2,
                   turnStartTime: matchState.turnStartTime,
                   timerDurationSeconds: matchState.timerDurationSeconds,
                   activeEmoji: matchState.playerIds.length > 2 ? matchState.playerEmojis[matchState.playerIds[2]] : null,
                ),
              ),
            ),

            // Left Player
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: PlayerAvatar(
                   user: currentUser, // Placeholder: Use actual left player
                   isCurrentTurn: matchState.currentTurnIndex == 1,
                   turnStartTime: matchState.turnStartTime,
                   timerDurationSeconds: matchState.timerDurationSeconds,
                   activeEmoji: matchState.playerIds.length > 1 ? matchState.playerEmojis[matchState.playerIds[1]] : null,
                ),
              ),
            ),

            // Right Player
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: PlayerAvatar(
                   user: currentUser, // Placeholder: Use actual right player
                   isCurrentTurn: matchState.currentTurnIndex == 3,
                   turnStartTime: matchState.turnStartTime,
                   timerDurationSeconds: matchState.timerDurationSeconds,
                   activeEmoji: matchState.playerIds.length > 3 ? matchState.playerEmojis[matchState.playerIds[3]] : null,
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
            
            // Local Player (Bottom Center)
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
                           ref.read(matchStateProvider.notifier).sendEmoji(currentUser.uid, e);
                           Future.delayed(const Duration(seconds: 3), () {
                              ref.read(matchStateProvider.notifier).clearEmoji(currentUser.uid);
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
                       user: currentUser,
                       isCurrentTurn: matchState.playerIds.isNotEmpty && matchState.playerIds[matchState.currentTurnIndex] == currentUser.uid,
                       turnStartTime: matchState.turnStartTime,
                       timerDurationSeconds: matchState.timerDurationSeconds,
                       activeEmoji: matchState.playerEmojis[currentUser.uid],
                    ),
                    if ((matchState.handCards[currentUser.uid]?.length ?? 0) > 0) ...[
                      const SizedBox(height: 16),
                      // Player Hand
                      SizedBox(
                        height: 120, // Enough height for the card
                        child: ListView.separated(
                          shrinkWrap: true,
                          scrollDirection: Axis.horizontal,
                          itemCount: matchState.handCards[currentUser.uid]!.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final card = matchState.handCards[currentUser.uid]![index];
                            return CardWidget(
                              card: card,
                              onTap: () {
                                 ref.read(matchStateProvider.notifier).playCard(currentUser.uid, card);
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
               _buildLobbyOverlay(context, ref, matchState, currentUser.uid),
             if (matchState.phase == GamePhase.preRoundCut)
               _buildPhaseOverlay('Waiting for the Cut...'),
             if (matchState.phase == GamePhase.dealingFasha)
               _buildPhaseOverlay('Memorize the Fasha! 5s...'),
             if (matchState.phase == GamePhase.shuffleVoting)
               _buildShuffleVoteOverlay(context, ref, matchState, currentUser.uid),
             if (matchState.phase == GamePhase.rematchVoting)
               _buildRematchVoteOverlay(context, ref, matchState, currentUser.uid),
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
                const Text('Waiting for Players...', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('Room ID: ${state.id}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 24),
                const Text('Connected Players:', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                ...state.playerIds.map((id) => Padding(
                   padding: const EdgeInsets.symmetric(vertical: 4.0),
                   child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         Icon(Icons.person, color: id == currentUid ? Colors.green : Colors.white54, size: 20),
                         const SizedBox(width: 8),
                         Text(id == currentUid ? "You" : "Player (UUID: ${id.substring(0, 5)}...)", style: TextStyle(color: id == currentUid ? Colors.green : Colors.white)),
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
                        label: const Text('Ready (Fill empty seats with Bots)'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                      )
                   else
                      Text('Waiting for human consent ($readyCount/$totalPlayers Ready)...', style: const TextStyle(color: Colors.orangeAccent, fontStyle: FontStyle.italic)),
                ] else
                   const Text('Room Full! Starting shortly...', style: TextStyle(color: Colors.green)),
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
               const Text('Deck Finished!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
               const SizedBox(height: 16),
               Text('Shuffle votes: ${state.shuffleVotes.length} / 4', style: const TextStyle(color: Colors.white70)),
               const SizedBox(height: 24),
               if (!hasVoted) Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   ElevatedButton(
                     onPressed: () => ref.read(matchStateProvider.notifier).voteShuffle(currentUid, true),
                     child: const Text('Shuffle (Yes)'),
                   ),
                   const SizedBox(width: 16),
                   ElevatedButton(
                     style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                     onPressed: () => ref.read(matchStateProvider.notifier).voteShuffle(currentUid, false),
                     child: const Text('Keep Sequence (No)', style: TextStyle(color: Colors.white)),
                   ),
                 ],
               ) else const Text('Waiting for other players...', style: TextStyle(color: Colors.white)),
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
               const Text('Match Over!', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
               Text(aWins ? 'Team A Wins!' : 'Team B Wins!', style: const TextStyle(color: Colors.greenAccent, fontSize: 20)),
               const SizedBox(height: 16),
               Text('Rematch votes: ${state.rematchVotes.length} / 4', style: const TextStyle(color: Colors.white70)),
               const SizedBox(height: 24),
               if (!hasVoted) Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   ElevatedButton(
                     onPressed: () => ref.read(matchStateProvider.notifier).voteRematch(currentUid, true),
                     child: const Text('Best of 3 (Yes)'),
                   ),
                   const SizedBox(width: 16),
                   ElevatedButton(
                     style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                     onPressed: () => ref.read(matchStateProvider.notifier).voteRematch(currentUid, false),
                     child: const Text('Leave Match (No)', style: TextStyle(color: Colors.white)),
                   ),
                 ],
               ) else const Text('Waiting for other players...', style: TextStyle(color: Colors.white)),
             ],
          ),
       ),
     );
  }
}
