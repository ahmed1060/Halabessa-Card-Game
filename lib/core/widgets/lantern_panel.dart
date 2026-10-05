import 'package:flutter/material.dart';
import '../../features/game/presentation/widgets/table_style.dart';

/// The mockup's quiet ivory surface; selection is a brass outline, not a glow.
class LanternPanel extends StatelessWidget {
  final Widget child;
  final bool selected;
  final EdgeInsetsGeometry padding;
  const LanternPanel({
    super.key,
    required this.child,
    this.selected = false,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: TableStyle.ivory,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: selected ? TableStyle.brass : TableStyle.ink,
        width: selected ? 2 : 1,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x26192638),
          offset: Offset(0, 3),
          blurRadius: 6,
        ),
      ],
    ),
    child: Padding(padding: padding, child: child),
  );
}
