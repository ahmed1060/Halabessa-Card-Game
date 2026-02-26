import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:easy_localization/easy_localization.dart';

import 'auth_screen.dart';
import '../providers/auth_providers.dart';
import '../../../home/presentation/pages/home_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          return const HomeScreen();
        }
        return const AuthScreen();
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Text('error_general'.tr(args: [error.toString()])),
        ),
      ),
    );
  }
}
