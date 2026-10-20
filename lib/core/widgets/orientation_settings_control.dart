import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/orientation_policy_provider.dart';
import '../providers/settings_provider.dart';
import '../../features/game/presentation/widgets/table_style.dart';

class OrientationSettingsControl extends ConsumerStatefulWidget {
  const OrientationSettingsControl({super.key});
  @override
  ConsumerState<OrientationSettingsControl> createState() =>
      _OrientationSettingsControlState();
}

class _OrientationSettingsControlState
    extends ConsumerState<OrientationSettingsControl> {
  bool _saving = false, _failed = false;
  Future<void> _setVisible(bool value) async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await ref.read(orientationPolicyWriterProvider)(value);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner =
        ref.watch(orientationSuperAdminProvider).asData?.value ?? false;
    final visible =
        ref.watch(orientationControlVisibleProvider).valueOrNull ?? false;
    if (!visible && !owner) return const SizedBox.shrink();
    final selected = ref.watch(
      settingsProvider.select((s) => s.gameOrientation),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('display_orientation'.tr(), style: TableStyle.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<GameOrientation>(
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(110, 64)),
                side: const WidgetStatePropertyAll(
                  BorderSide(color: TableStyle.brass),
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? TableStyle.brass
                      : TableStyle.ink,
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? TableStyle.ink
                      : TableStyle.ivory,
                ),
                textStyle: WidgetStatePropertyAll(
                  TableStyle.label.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              segments: [
                ButtonSegment(
                  value: GameOrientation.portrait,
                  icon: const Icon(Icons.stay_current_portrait),
                  label: Text('orientation_portrait'.tr()),
                ),
                ButtonSegment(
                  value: GameOrientation.landscape,
                  icon: const Icon(Icons.stay_current_landscape),
                  label: Text('orientation_landscape'.tr()),
                ),
              ],
              selected: {selected},
              onSelectionChanged: (value) => ref
                  .read(settingsProvider.notifier)
                  .setGameOrientation(value.single),
            ),
            if (owner)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    activeColor: TableStyle.brass,
                    checkColor: TableStyle.ink,
                    key: const ValueKey('orientation-player-visibility'),
                    value: visible,
                    onChanged: _saving ? null : (value) => _setVisible(value!),
                  ),
                  Flexible(
                    child: Text(
                      'show_orientation_players'.tr(),
                      style: TableStyle.detail,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text('game_orientation_help'.tr(), style: TableStyle.detail),
        if (_failed)
          Text(
            'orientation_policy_save_failed'.tr(),
            style: const TextStyle(color: TableStyle.red),
          ),
      ],
    );
  }
}
