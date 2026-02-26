import 'package:flutter/material.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/core/theme/theme_config.dart';

class UserAvatar extends StatelessWidget {
  final AppUser user;
  final double radius;
  final VoidCallback? onTap;
  final bool showRankBorder;

  const UserAvatar({
    super.key,
    required this.user,
    this.radius = 20,
    this.onTap,
    this.showRankBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    // Determine border color based on points/rank
    Color borderColor = Colors.white24;
    double glowOpacity = 0.0;

    if (showRankBorder) {
      if (user.points > 1000) {
        borderColor = Colors.amber;
        glowOpacity = 0.3;
      } else if (user.points > 500) {
        borderColor = Colors.blueGrey.shade200;
        glowOpacity = 0.2;
      } else if (user.points > 100) {
        borderColor = Colors.orange.shade700;
        glowOpacity = 0.1;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: glowOpacity > 0 ? [
            BoxShadow(
              color: borderColor.withOpacity(glowOpacity),
              blurRadius: 8,
              spreadRadius: 2,
            )
          ] : null,
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: borderColor,
          child: CircleAvatar(
            radius: radius - 2,
            backgroundColor: ThemeConfig.darkBg,
            backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
            child: user.avatarUrl == null
                ? Text(
                    user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: radius * 0.8,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
