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
              padding: EdgeInsets.all(isCurrentTurn ? 4 : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: isCurrentTurn
                    ? Border.all(color: Colors.transparent, width: 3) // Border is now handled by the indicator
                    : null,
              ),
              child: CircleAvatar(
                radius: size / 2,
                backgroundColor: Colors.teal.shade200,
                backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                child: user.avatarUrl == null
                    ? Text(
                        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: size * 0.4, color: Colors.white),
                      )
                    : null,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 4),
        
        // Player Name & Points
        Text(
          user.displayName,
          style: TextStyle(
            fontWeight: isCurrentTurn ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
