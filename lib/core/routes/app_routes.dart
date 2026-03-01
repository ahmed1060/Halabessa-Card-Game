import 'package:flutter/material.dart';

import '../../features/auth/presentation/pages/auth_wrapper.dart';
import '../../features/home/presentation/pages/home_screen.dart';
import '../../features/game/presentation/pages/game_board_screen.dart';
import '../../features/auth/presentation/pages/profile_screen.dart';
import '../../features/home/presentation/pages/store_screen.dart';
import '../../features/home/presentation/pages/admin_audio_management_screen.dart';

class AppRoutes {
  static const String initial = '/';
  static const String home = '/home';
  static const String game = '/game';
  static const String profile = '/profile';
  static const String store = '/store';
  static const String adminAudio = '/admin/audio';

  static Map<String, WidgetBuilder> get routes => {
        initial: (context) => const AuthWrapper(),
        home: (context) => const HomeScreen(),
        game: (context) => const GameBoardScreen(),
        profile: (context) => const ProfileScreen(),
        store: (context) => const StoreScreen(),
        adminAudio: (context) => const AdminAudioManagementScreen(),
      };
}

class PlaceholderView extends StatelessWidget {
  final String title;
  const PlaceholderView({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('Placeholder: $title')),
    );
  }
}
