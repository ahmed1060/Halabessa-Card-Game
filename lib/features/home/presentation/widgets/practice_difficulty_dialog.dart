import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../game/domain/models/bot_difficulty.dart';
import '../../../game/presentation/widgets/table_style.dart';

class PracticeDifficultyDialog extends StatelessWidget {
  const PracticeDifficultyDialog({super.key});
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: TableStyle.ivory,
    title: Text(
      'training_difficulty'.tr(),
      style: TableStyle.label.copyWith(color: TableStyle.ink),
    ),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final level in BotDifficulty.values)
          ListTile(
            key: ValueKey('practice-${level.name}'),
            leading: Icon(Icons.smart_toy_outlined, color: TableStyle.ink),
            title: Text(
              'bot_difficulty_${level.name}'.tr(),
              style: TableStyle.label.copyWith(color: TableStyle.ink),
            ),
            subtitle: Text(
              'bot_strategy_${level.name}'.tr(),
              style: TableStyle.detail.copyWith(color: TableStyle.ink),
            ),
            onTap: () => Navigator.pop(context, level),
          ),
      ],
    ),
  );
}
