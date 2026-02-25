import 'package:flutter/material.dart';
import '../../../auth/domain/models/app_user.dart';

class PlayerAvatar extends StatelessWidget {
  final AppUser user;
  final bool isCurrentTurn;
  final String? activeEmoji;
  final double size;
  final DateTime? turnStartTime;
  final int timerDurationSeconds;

  const PlayerAvatar({
    super.key,
    required this.user,
    this.isCurrentTurn = false,
    this.activeEmoji,
    this.size = 60,
    this.turnStartTime,
    this.timerDurationSeconds = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Emoji Reaction Bubble
        SizedBox(
          height: 30,
          child: AnimatedOpacity(
            opacity: activeEmoji != null ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: activeEmoji != null
                ? Text(activeEmoji!, style: const TextStyle(fontSize: 24))
                : const SizedBox.shrink(),
          ),
        ),
        
        // Avatar Ring with Timer
        Stack(
          alignment: Alignment.center,
          children: [
            if (isCurrentTurn && turnStartTime != null && timerDurationSeconds > 0)
              SizedBox(
                width: size + 8,
                height: size + 8,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: (1.0 - (DateTime.now().difference(turnStartTime!).inMilliseconds / (timerDurationSeconds * 1000))).clamp(0.0, 1.0),
                    end: 0.0,
                  ),
                  duration: Duration(
                    milliseconds: ((1.0 - (DateTime.now().difference(turnStartTime!).inMilliseconds / (timerDurationSeconds * 1000))).clamp(0.0, 1.0) * (timerDurationSeconds * 1000)).toInt(),
                  ),
                  builder: (context, value, child) {
                    return CircularProgressIndicator(
                      value: value,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        value > 0.3 ? Colors.amber : Colors.red,
                      ),
                      strokeWidth: 4,
                    );
                  },
                ),
              ),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: isCurrentTurn ? [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ] : null,
              ),
              child: Container(
                padding: EdgeInsets.all(isCurrentTurn ? 2 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: isCurrentTurn
                      ? Border.all(color: Colors.amber, width: 2)
                      : Border.all(color: Colors.white24, width: 1),
                ),
                child: CircleAvatar(
                  radius: size / 2,
                  backgroundColor: isCurrentTurn ? Colors.amber.shade100 : Colors.teal.shade200,
                  backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                  child: user.avatarUrl == null
                      ? Text(
                          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: size * 0.4, 
                            color: isCurrentTurn ? Colors.black87 : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Player Name & Points - Glassmorphism Style
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isCurrentTurn ? Colors.amber.withOpacity(0.5) : Colors.white12, width: 0.5),
            boxShadow: isCurrentTurn ? [
              BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 4, spreadRadius: 1)
            ] : null,
          ),
          child: Text(
            user.displayName,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isCurrentTurn ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
