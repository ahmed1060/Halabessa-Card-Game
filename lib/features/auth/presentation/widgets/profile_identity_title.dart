import 'package:flutter/material.dart';
import '../../../game/presentation/widgets/table_style.dart';

/// Long identities wrap without pushing badges outside the available width.
class ProfileIdentityTitle extends StatelessWidget {
  final String name;
  final String? badge;
  const ProfileIdentityTitle({super.key, required this.name, this.badge});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Flexible(
        child: Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: TableStyle.ivory,
            fontWeight: FontWeight.bold,
            fontFamily: 'LanternDisplay',
            fontFamilyFallback: const ['LanternArabic'],
          ),
        ),
      ),
      if (badge != null)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: Chip(label: Text(badge!), backgroundColor: TableStyle.red),
        ),
    ],
  );
}
