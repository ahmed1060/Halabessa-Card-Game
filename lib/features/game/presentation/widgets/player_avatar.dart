import 'package:flutter/material.dart';
import '../../../auth/domain/models/app_user.dart';

class PlayerAvatar extends StatelessWidget {
  final AppUser user;
  final bool isCurrentTurn;
  final String? activeEmoji;
  final double size;
  final DateTime? turnStartTime;
  final int timerDurationSeconds;
  final Color? teamColor;
  final String? activeMessage;

  const PlayerAvatar({
    super.key,
    required this.user,
    this.isCurrentTurn = false,
    this.activeEmoji,
    this.size = 60,
    this.turnStartTime,
    this.timerDurationSeconds = 10,
    this.teamColor,
    this.activeMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Message/Emoji Bubble Container
        SizedBox(
          height: 40,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Emoji Reaction
              AnimatedOpacity(
                opacity: activeEmoji != null && activeMessage == null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: activeEmoji != null
                    ? Text(activeEmoji!, style: const TextStyle(fontSize: 24))
                    : const SizedBox.shrink(),
              ),
              // Chat Message Bubble
              AnimatedOpacity(
                opacity: activeMessage != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: activeMessage != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.24), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Text(
                              activeMessage!,
                              style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            // Triangle pointer
                            Positioned(
                              bottom: -8,
                              left: 10,
                              child: CustomPaint(
                                painter: TrianglePainter(color: Colors.white),
                                size: const Size(12, 8),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
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
                        value > 0.3 ? Colors.white : Colors.redAccent,
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
                    color: Colors.white.withOpacity(0.5),
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
                      ? Border.all(color: Colors.white, width: 2)
                      : Border.all(color: teamColor?.withOpacity(0.5) ?? Colors.white24, width: 1.5),
                ),
                child: CircleAvatar(
                  radius: size / 2,
                  backgroundColor: teamColor?.withOpacity(0.2) ?? (isCurrentTurn ? Colors.white10 : Colors.teal.shade200),
                  backgroundImage: user.avatarUrl != null
                      ? (user.avatarUrl!.startsWith('assets/')
                          ? AssetImage(user.avatarUrl!) as ImageProvider
                          : NetworkImage(user.avatarUrl!))
                      : null,
                  child: user.avatarUrl == null
                      ? (user.uid.startsWith('bot_')
                          ? Icon(Icons.smart_toy_rounded, size: size * 0.6, color: Colors.white)
                          : Text(
                              user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: size * 0.4, 
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ))
                      : null,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Player Name - Glassmorphism Style with Team Color
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: teamColor ?? (isCurrentTurn ? Colors.white54 : Colors.white12), width: 1.5),
            boxShadow: isCurrentTurn ? [
              BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 4, spreadRadius: 1)
            ] : null,
          ),
          child: Text(
            user.displayName,
            style: TextStyle(
              color: teamColor ?? Colors.white,
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

class TrianglePainter extends CustomPainter {
  final Color color;
  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
