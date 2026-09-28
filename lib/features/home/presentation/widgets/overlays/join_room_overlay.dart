import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import '../room_entry_forms.dart';

class JoinRoomOverlay extends ConsumerWidget {
  final String playerId;
  final String displayName;

  const JoinRoomOverlay({super.key, required this.playerId,
    required this.displayName});

  @override
  Widget build(BuildContext context, WidgetRef ref) => RoomEntrySheet(
    child: RoomJoinForm(
      text: (key) => key.tr(),
      onJoin: (code) => ref.read(matchStateProvider.notifier)
        .joinMatch(code, playerId, displayName),
      onJoined: () {
        final navigator = Navigator.of(context);
        navigator.pop();
        navigator.pushNamed('/game');
      },
    ),
  );
}
