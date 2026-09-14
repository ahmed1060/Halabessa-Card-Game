import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/core/theme/theme_config.dart';
import 'package:halabessa/features/game/domain/providers/game_providers.dart';
import 'package:halabessa/core/utils/error_handler.dart';

class JoinRoomOverlay extends ConsumerStatefulWidget {
  final String playerId;
  final String displayName;

  const JoinRoomOverlay({
    super.key,
    required this.playerId,
    required this.displayName,
  });

  @override
  ConsumerState<JoinRoomOverlay> createState() => _JoinRoomOverlayState();
}

class _JoinRoomOverlayState extends ConsumerState<JoinRoomOverlay> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

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
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
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

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'join_room'.tr(),
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

                    Text(
                      'enter_code'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildRoomCodeInput(),

                    const SizedBox(height: 32),

                    GestureDetector(
                      onTap: _isLoading ? null : _joinMatch,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: ThemeConfig.goldAccent,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: ThemeConfig.goldAccent.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5)),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.black, strokeWidth: 2))
                            : Text(
                                'join'.tr().toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    letterSpacing: 2),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomCodeInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThemeConfig.goldAccent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: ThemeConfig.goldAccent.withOpacity(0.05), blurRadius: 20, spreadRadius: -5),
        ],
      ),
      child: TextField(
        controller: _controller,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: 8,
          fontFamily: 'monospace',
        ),
        keyboardType: TextInputType.text,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [
          LengthLimitingTextInputFormatter(10),
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
        ],
        decoration: InputDecoration(
          hintText: 'ROOM CODE',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.12), letterSpacing: 4, fontSize: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  void _joinMatch() async {
    final roomId = _controller.text.trim().toUpperCase();
    if (roomId.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(matchStateProvider.notifier).joinMatch(
        roomId,
        widget.playerId,
        widget.displayName,
      );
      if (mounted) {
        Navigator.pop(context);
        Navigator.pushNamed(context, '/game');
      }
    } catch (e) {
      debugPrint('Join error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.getAuthErrorMessage(e))),
        );
      }
    }
  }
}
