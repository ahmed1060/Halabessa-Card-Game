import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../features/game/presentation/widgets/table_style.dart';
import 'lantern_page_frame.dart';
import 'lantern_panel.dart';

/// Existing data practices and gameplay help, not a fabricated legal policy or
/// an unconfigured contact form. Account deletion remains an explicit gap.
class AccountInformationScreen extends StatelessWidget {
  final bool support;
  const AccountInformationScreen({super.key, this.support = false});
  @override
  Widget build(BuildContext context) => LanternPageFrame(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        toolbarHeight: 110,
        title: LanternPageTitle(
          title: (support ? 'ui_support' : 'ui_privacy').tr(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              LanternPanel(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      support
                          ? Icons.help_outline_rounded
                          : Icons.shield_outlined,
                      color: TableStyle.ink,
                      size: 44,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      (support ? 'ui_support_detail' : 'ui_privacy_detail')
                          .tr(),
                      style: TableStyle.label.copyWith(color: TableStyle.ink),
                    ),
                    const SizedBox(height: 20),
                    if (!support)
                      Text(
                        'ui_deletion_unavailable'.tr(),
                        style: TableStyle.detail.copyWith(
                          color: TableStyle.ink,
                        ),
                      ),
                    if (support)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: TableStyle.ink,
                          foregroundColor: TableStyle.ivory,
                          minimumSize: const Size(48, 52),
                        ),
                        onPressed: () => Navigator.pushNamed(context, '/help'),
                        icon: const Icon(Icons.menu_book_rounded),
                        label: Text('help_title'.tr()),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
