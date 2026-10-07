import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/game/presentation/widgets/table_style.dart';
import 'lantern_page_frame.dart';

enum ReleasePolicy { privacy, terms }

/// The website and native screens use the same checked-in notice text.
/// Opening these notices does not require an authentication provider.
class ReleasePolicyScreen extends StatefulWidget {
  final ReleasePolicy policy;
  const ReleasePolicyScreen({super.key, required this.policy});
  @override
  State<ReleasePolicyScreen> createState() => _ReleasePolicyScreenState();
}

class _ReleasePolicyScreenState extends State<ReleasePolicyScreen> {
  late final Future<Map<String, dynamic>> _text = DefaultAssetBundle.of(context)
      .loadString('assets/legal/${widget.policy.name}.json')
      .then((text) => jsonDecode(text) as Map<String, dynamic>);
  @override
  Widget build(BuildContext context) => LanternPageFrame(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: TableStyle.ink),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _text,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: SelectableText(
                'WeirdPuzz · weirdpuzz@gmail.com',
                style: TableStyle.label,
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final language = Localizations.localeOf(context).languageCode == 'ar'
              ? 'ar'
              : 'en';
          final text = snapshot.data![language] as Map<String, dynamic>;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: TableStyle.ink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          text['title'] as String,
                          style: TableStyle.label.copyWith(
                            fontSize: 26,
                            color: TableStyle.brass,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          text['updated'] as String,
                          style: TableStyle.detail,
                        ),
                        for (final section in text['sections'] as List) ...[
                          const SizedBox(height: 24),
                          Text(
                            section['title'] as String,
                            style: TableStyle.label.copyWith(
                              fontSize: 18,
                              color: TableStyle.brass,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            section['body'] as String,
                            style: TableStyle.label.copyWith(
                              fontSize: 16,
                              height: 1.7,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class ReleasePolicyLinks extends StatelessWidget {
  const ReleasePolicyLinks({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    children: [
      for (final policy in ReleasePolicy.values)
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ReleasePolicyScreen(policy: policy),
            ),
          ),
          child: Text(
            (policy == ReleasePolicy.privacy ? 'ui_privacy' : 'ui_rules_of_use')
                .tr(),
          ),
        ),
    ],
  );
}
