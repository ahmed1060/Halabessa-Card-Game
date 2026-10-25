import 'package:flutter/material.dart';
import 'table_style.dart';

/// A visual projection of an accepted room message, never a send acknowledgement.
class TableChatBubble extends StatelessWidget {
  const TableChatBubble({super.key, required this.message, this.identity});
  final String? message;
  final String? identity;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, .12),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: message == null
          ? const SizedBox.shrink(key: ValueKey('no-bubble'))
          : Container(
              key: ValueKey(identity ?? message),
              constraints: const BoxConstraints(maxWidth: 174),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: TableStyle.ivory,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: TableStyle.brass.withValues(alpha: .6),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                message!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TableStyle.detail.copyWith(
                  color: TableStyle.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    ),
  );
}
