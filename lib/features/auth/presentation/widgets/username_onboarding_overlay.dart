import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';
import 'username_editor.dart';

class UsernameOnboardingOverlay extends ConsumerWidget {
  const UsernameOnboardingOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => UsernameEditor(
    title: 'onboarding_title'.tr(),
    description: 'onboarding_desc'.tr(),
    fieldLabel: 'username_label'.tr(),
    saveLabel: 'save'.tr(),
    invalidMessage: 'username_format_hint'.tr(),
    takenMessage: 'username_taken'.tr(),
    failureMessage: 'profile_save_retry'.tr(),
    retryLabel: 'retry_action'.tr(),
    onCheck: (value) => ref.read(authRepositoryProvider).isUsernameAvailable(
      value, currentUid: ref.read(currentUserProvider)?.uid),
    onSave: (value) => ref.read(authRepositoryProvider).updateProfile(username: value),
    onSaved: () {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('username_updated_success'.tr())));
    },
    onClose: () => Navigator.pop(context),
  );
}
