import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/age_eligibility_provider.dart';
import 'lantern_page_frame.dart';
import '../../features/game/presentation/widgets/table_style.dart';

class AgeEligibilityScreen extends ConsumerStatefulWidget {
  const AgeEligibilityScreen({super.key});
  @override
  ConsumerState<AgeEligibilityScreen> createState() =>
      _AgeEligibilityScreenState();
}

class _AgeEligibilityScreenState extends ConsumerState<AgeEligibilityScreen> {
  DateTime? _date;
  bool _saving = false;
  bool _failed = false;
  @override
  Widget build(BuildContext context) {
    final blocked = ref.watch(ageEligibilityProvider) == AgeEligibility.blocked;
    return LanternPageFrame(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Card(
                  color: TableStyle.ink,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          color: TableStyle.brass,
                          size: 48,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          (blocked ? 'ui_age_blocked_title' : 'ui_age_title')
                              .tr(),
                          style: TableStyle.label.copyWith(fontSize: 24),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          (blocked ? 'ui_age_blocked_detail' : 'ui_age_detail')
                              .tr(),
                          style: TableStyle.label,
                        ),
                        if (!blocked) ...[
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () async {
                                    final now = DateTime.now();
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _date ?? now,
                                      firstDate: DateTime(1900),
                                      lastDate: now,
                                    );
                                    if (mounted && date != null)
                                      setState(() => _date = date);
                                  },
                            icon: const Icon(Icons.calendar_month),
                            label: Text(
                              _date == null
                                  ? 'ui_age_date'.tr()
                                  : MaterialLocalizations.of(
                                      context,
                                    ).formatMediumDate(_date!),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _date == null || _saving
                                ? null
                                : () async {
                                    setState(() {
                                      _saving = true;
                                      _failed = false;
                                    });
                                    try {
                                      await ref
                                          .read(ageEligibilityProvider.notifier)
                                          .submit(_date!);
                                    } catch (_) {
                                      if (mounted)
                                        setState(() => _failed = true);
                                    } finally {
                                      if (mounted)
                                        setState(() => _saving = false);
                                    }
                                  },
                            child: Text('ui_age_continue'.tr()),
                          ),
                          if (_failed)
                            Text(
                              'match_action_retry'.tr(),
                              style: TableStyle.detail,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
