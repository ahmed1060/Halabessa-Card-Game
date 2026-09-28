import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import '../room_entry_forms.dart';

class CreateRoomOverlay extends ConsumerWidget {
  final String playerId;
  final String displayName;

  const CreateRoomOverlay({super.key, required this.playerId,
    required this.displayName});

  @override
  Widget build(BuildContext context, WidgetRef ref) => RoomEntrySheet(
    child: RoomCreationForm(
      text: (key) => key.tr(),
      onCreate: (config) => ref.read(matchStateProvider.notifier).initializeMatch(
        playerId, displayName, config.mode,
        maxPoints: config.maxPoints,
        timerDurationSeconds: config.timerSeconds,
        isPublic: config.isPublic),
      onCreated: () {
        final navigator = Navigator.of(context);
        navigator.pop();
        navigator.pushNamed('/game');
      },
    ),
  );
}
