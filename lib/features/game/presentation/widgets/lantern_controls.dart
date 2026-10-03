import 'package:flutter/material.dart';
import 'table_style.dart';

class LanternControlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const LanternControlButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: SizedBox(
      width: MediaQuery.sizeOf(context).width < 350 ? 64 : 76,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: TableStyle.ink,
          foregroundColor: TableStyle.ivory,
          side: const BorderSide(color: TableStyle.mint, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Semantics(
          label: label,
          excludeSemantics: true,
          child: Icon(icon, size: 25),
        ),
      ),
    ),
  );
}

class LanternTurnBadge extends StatelessWidget {
  final String title;
  final String hint;
  final bool active;
  const LanternTurnBadge({
    super.key,
    required this.title,
    required this.hint,
    required this.active,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.auto_awesome,
                  color: TableStyle.brass,
                  size: 18,
                ),
              ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: active ? TableStyle.brass : TableStyle.ink,
                  border: Border.all(
                    color: active ? TableStyle.ink : TableStyle.mint,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TableStyle.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: active ? TableStyle.ink : TableStyle.ivory,
                  ),
                ),
              ),
            ),
            if (active)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.auto_awesome,
                  color: TableStyle.brass,
                  size: 18,
                ),
              ),
          ],
        ),
        if (hint.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              hint,
              textAlign: TextAlign.center,
              style: TableStyle.detail.copyWith(color: TableStyle.ivory),
            ),
          ),
      ],
    ),
  );
}
