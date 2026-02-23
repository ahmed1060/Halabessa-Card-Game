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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('7alabessa Match'),
            Text(
              'Room ID: \${matchState.id}',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          const Center(
             child: Padding(
               padding: EdgeInsets.symmetric(horizontal: 16.0),
               child: Text('Score: \${matchState.teamAScore} - \${matchState.teamBScore}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                    const SizedBox(height: 16),
                    // Player Hand
                    SizedBox(
                      height: 120, // Enough height for the card
                      child: ListView.separated(
                        shrinkWrap: true,
                        scrollDirection: Axis.horizontal,
                        itemCount: matchState.handCards[currentUser.uid]?.length ?? 0,
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
                ),
              ),
            ),
            
            // Phase indicator overlay
             if (matchState.phase == GamePhase.preRoundCut)
               _buildPhaseOverlay('Waiting for the Cut...'),
             if (matchState.phase == GamePhase.dealingFasha)
               _buildPhaseOverlay('Memorize the Fasha! 5s...'),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseOverlay(String text) {
     return Center(
       child: Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black54,
          child: Text(
            text, 
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
          ),
       ),
     );
  }
}
