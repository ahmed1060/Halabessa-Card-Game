import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/age_eligibility_provider.dart';
import '../../../../core/providers/native_play_provider.dart';
import '../../../../core/widgets/lantern_page_frame.dart';
import '../../../../core/widgets/age_eligibility_screen.dart';
import '../../../../core/widgets/release_policy_screen.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../game/presentation/widgets/table_style.dart';
import '../../data/repositories/birth_date_store.dart';
import '../pages/auth_screen.dart';
import '../providers/auth_providers.dart';
import '../providers/birth_date_providers.dart';

class AccountBirthDateGate extends ConsumerWidget {
  const AccountBirthDateGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(offlineSessionProvider)) return child;
    final uid = ref.watch(sessionUidProvider);
    if (uid == null) return const AuthScreen();
    if (ref.watch(ageEligibilityProvider) == AgeEligibility.blocked) {
      return const AgeEligibilityScreen(footer: _AccountAccessActions());
    }
    final date = ref.watch(profileBirthDateProvider);
    final savedDate = date.asData?.value;
    if (savedDate != null &&
        validProfileBirthDate(savedDate, DateTime.now().toUtc())) {
      return child;
    }
    return LanternPageFrame(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    date.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => FilledButton(
                        onPressed: () =>
                            ref.invalidate(profileBirthDateProvider),
                        child: Text('profile_birth_date_retry'.tr()),
                      ),
                      data: (_) => BirthDateForm(
                        key: ValueKey(uid),
                        onboarding: true,
                        initialDate: date.asData?.value,
                        onUnderage: (value) => ref
                            .read(ageEligibilityProvider.notifier)
                            .submit(
                              value,
                              today: DateTime.now().toUtc(),
                              recheck: true,
                            ),
                        onSave: (value) async {
                          await ref.read(saveProfileBirthDateProvider)(value);
                          await ref
                              .read(ageEligibilityProvider.notifier)
                              .submit(
                                value,
                                today: DateTime.now().toUtc(),
                                recheck: true,
                              );
                        },
                      ),
                    ),
                    const _AccountAccessActions(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileBirthDateTile extends ConsumerWidget {
  const ProfileBirthDateTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(offlineSessionProvider)) return const SizedBox.shrink();
    final date = ref.watch(profileBirthDateProvider);
    return ListTile(
      leading: const Icon(Icons.cake_outlined, color: TableStyle.brass),
      title: Text('profile_birth_date'.tr(), style: TableStyle.label),
      subtitle: Text(
        date.hasError
            ? 'profile_birth_date_retry'.tr()
            : date.value == null
            ? 'profile_birth_date_private'.tr()
            : DateFormat.yMMMd(context.locale.toString()).format(date.value!),
        style: TableStyle.detail,
      ),
      trailing: const Icon(Icons.edit_outlined, color: TableStyle.mint),
      onTap: date.isLoading
          ? null
          : date.hasError
          ? () => ref.invalidate(profileBirthDateProvider)
          : () => showDialog<void>(
              context: context,
              builder: (dialogContext) => Dialog(
                backgroundColor: TableStyle.ink,
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: BirthDateForm(
                      initialDate: date.asData?.value,
                      onSave: (value) async {
                        await ref.read(saveProfileBirthDateProvider)(value);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      },
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class BirthDateForm extends StatefulWidget {
  const BirthDateForm({
    super.key,
    required this.onSave,
    this.initialDate,
    this.onUnderage,
    this.onboarding = false,
    this.pickDate,
  });
  final Future<void> Function(DateTime) onSave;
  final Future<void> Function(DateTime)? onUnderage;
  final DateTime? initialDate;
  final bool onboarding;
  final Future<DateTime?> Function(BuildContext, DateTime?)? pickDate;
  @override
  State<BirthDateForm> createState() => _BirthDateFormState();
}

class _BirthDateFormState extends State<BirthDateForm> {
  late DateTime? _date = widget.initialDate;
  bool _saving = false;
  String? _error;

  Future<void> _pick() async {
    final today = DateTime.now().toUtc();
    final value = widget.pickDate != null
        ? await widget.pickDate!(context, _date)
        : await showDatePicker(
            context: context,
            helpText: 'profile_birth_date'.tr(),
            initialDate:
                _date ?? DateTime(today.year - 18, today.month, today.day),
            firstDate: DateTime(1900),
            lastDate: today,
          );
    if (mounted && value != null) {
      setState(() {
        _date = birthDateOnly(value);
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _date == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (!validProfileBirthDate(_date!, DateTime.now().toUtc())) {
        if (mounted) setState(() => _error = 'ui_age_blocked_detail');
        if (_date!.year >= 1900 &&
            !isAtLeast13(_date!, DateTime.now().toUtc())) {
          await widget.onUnderage?.call(_date!);
        }
        return;
      }
      await widget.onSave(_date!);
    } catch (_) {
      if (mounted) setState(() => _error = 'profile_birth_date_save_failed');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: TableStyle.ink,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: TableStyle.brass.withValues(alpha: .7)),
    ),
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.cake_outlined, color: TableStyle.brass, size: 40),
        const SizedBox(height: 16),
        Text(
          (widget.onboarding
                  ? 'profile_birth_date_complete'
                  : 'profile_birth_date')
              .tr(),
          textAlign: TextAlign.center,
          style: TableStyle.label.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 12),
        Text(
          'profile_birth_date_private'.tr(),
          textAlign: TextAlign.center,
          style: TableStyle.detail,
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          key: const ValueKey('profile-birth-date-picker'),
          onPressed: _saving ? null : _pick,
          icon: const Icon(Icons.calendar_month),
          label: Text(
            _date == null
                ? 'ui_age_date'.tr()
                : DateFormat.yMMMd(context.locale.toString()).format(_date!),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!.tr(),
              style: TableStyle.detail.copyWith(color: TableStyle.red),
            ),
          ),
        const SizedBox(height: 20),
        const ReleasePolicyLinks(),
        FilledButton(
          key: const ValueKey('profile-birth-date-save'),
          onPressed: _saving || _date == null ? null : _save,
          child: Text(
            (widget.onboarding ? 'profile_birth_date_continue' : 'save_changes')
                .tr(),
          ),
        ),
      ],
    ),
  );
}

class _AccountAccessActions extends ConsumerWidget {
  const _AccountAccessActions();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
    alignment: WrapAlignment.center,
    children: [
      TextButton(
        onPressed: () async {
          try {
            await ref.read(authRepositoryProvider).signOut();
          } catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ErrorHandler.getAuthErrorMessage(error)),
                ),
              );
            }
          }
        },
        child: Text('log_out'.tr()),
      ),
      TextButton(
        onPressed: () => Navigator.pushNamed(context, '/account/delete'),
        child: Text('ui_delete_account'.tr()),
      ),
    ],
  );
}
