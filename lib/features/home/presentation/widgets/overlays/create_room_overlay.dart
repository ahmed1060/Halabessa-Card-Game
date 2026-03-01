import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import 'package:halabessa/features/game/domain/models/match_state.dart';

class CreateRoomOverlay extends ConsumerStatefulWidget {
  final String playerId;
  final String displayName;

  const CreateRoomOverlay({
    super.key,
    required this.playerId,
    required this.displayName,
  });

  @override
  ConsumerState<CreateRoomOverlay> createState() => _CreateRoomOverlayState();
}

class _CreateRoomOverlayState extends ConsumerState<CreateRoomOverlay> {
  int _selectedTargetScore = 41;
  int _selectedTimerSeconds = 10;
  bool _isPublic = false;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'create_room'.tr(),
              style: const TextStyle(
                color: ThemeConfig.goldAccent,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: ThemeConfig.fontHeading,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            _buildLabel('select_target_score'.tr()),
            const SizedBox(height: 12),
            _buildScoreSelector(),
            const SizedBox(height: 24),

            _buildLabel('select_timer'.tr()),
            const SizedBox(height: 12),
            _buildTimerSelector(),
            const SizedBox(height: 24),

            _buildLabel('select_game_mode'.tr()),
            const SizedBox(height: 12),
            _buildPublicSwitch(),
            const SizedBox(height: 40),

            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: 'classic_mode'.tr(),
                    isPrimary: true,
                    onTap: () => _createMatch(GameMode.classic),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    label: 'tafweet_mode'.tr(),
                    isPrimary: false,
                    accentColor: Colors.deepPurpleAccent,
                    onTap: () => _createMatch(GameMode.tafweet),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: Colors.white.withOpacity(0.5),
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildScoreSelector() {
    final options = [
      {'val': 21, 'label': '21'},
      {'val': 41, 'label': '41'},
      {'val': 61, 'label': '61'},
    ];

    return Row(
      children: options.map((opt) {
        final isSelected = _selectedTargetScore == opt['val'];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedTargetScore = opt['val'] as int),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isSelected ? ThemeConfig.goldAccent : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? ThemeConfig.goldAccent : Colors.white10),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(color: ThemeConfig.goldAccent.withOpacity(0.3), blurRadius: 10, spreadRadius: 1),
                ],
              ),
              child: Column(
                children: [
                   Text(
                    opt['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'points'.tr(),
                    style: TextStyle(
                      color: isSelected ? Colors.black54 : Colors.white38,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimerSelector() {
    final options = [
      {'val': 5, 'label': '5s'},
      {'val': 10, 'label': '10s'},
      {'val': 15, 'label': '15s'},
      {'val': 0, 'label': '∞'},
    ];

    return Row(
      children: options.map((opt) {
        final isSelected = _selectedTimerSeconds == opt['val'];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedTimerSeconds = opt['val'] as int),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? ThemeConfig.primaryTeal : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? ThemeConfig.primaryTeal : Colors.white10),
              ),
              child: Text(
                opt['label'] as String,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPublicSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: SwitchListTile.adaptive(
        title: Text('public_room'.tr(), style: const TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: Text('public_room_desc'.tr(), style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
        value: _isPublic,
        activeColor: ThemeConfig.goldAccent,
        onChanged: (val) => setState(() => _isPublic = val),
      ),
    );
  }

  Widget _buildActionButton({required String label, required bool isPrimary, required VoidCallback onTap, Color? accentColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isPrimary ? ThemeConfig.primaryTeal : (accentColor ?? Colors.white.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (isPrimary)
              BoxShadow(color: ThemeConfig.primaryTeal.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
        ),
      ),
    );
  }

  void _createMatch(GameMode mode) async {
    try {
      ref.read(matchStateProvider.notifier).initializeMatch(
        widget.playerId,
        widget.displayName,
        mode,
        maxPoints: _selectedTargetScore,
        timerDurationSeconds: _selectedTimerSeconds,
        isPublic: _isPublic,
      );
      Navigator.pop(context);
      Navigator.pushNamed(context, '/game');
    } catch (e) {
      debugPrint('Match init error: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error initializing match: $e')));
      }
    }
  }
}
