import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_screen.dart';
import '../widgets/profile_birth_date.dart';
import '../providers/auth_providers.dart';
import '../../../home/presentation/pages/home_screen.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/services/asset_preloader_service.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../../core/services/account_deletion_service.dart';
import '../../../../core/widgets/account_deletion_screen.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool _assetsPreloaded = false;
  bool _deletionChecked = false;
  bool _hasDeletionReceipt = false;
  bool _deletionReadFailed = false;
  bool _splashReadable = false;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _initAssets();
    _checkDeletionReceipt();
    // Give the real loading surface one readable beat, starting only after
    // it has painted. This does not fabricate progress or wait for Unity.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _splashTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) setState(() => _splashReadable = true);
      });
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkDeletionReceipt() async {
    try {
      final receipt = await DeletionReceipt.load();
      if (mounted) {
        setState(() {
          _deletionChecked = true;
          _deletionReadFailed = false;
          _hasDeletionReceipt = receipt != null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _deletionReadFailed = true);
    }
  }

  Future<void> _initAssets() async {
    final preloader = ref.read(assetPreloaderServiceProvider);

    // We wait for the first frame to ensure context is available for preloader
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await preloader.preloadAll(context);
      } catch (error, stackTrace) {
        debugPrint('Asset preloading failed: $error\n$stackTrace');
      } finally {
        if (mounted) {
          setState(() => _assetsPreloaded = true);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_deletionReadFailed) {
      final arabic = Localizations.localeOf(context).languageCode == 'ar';
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: _checkDeletionReceipt,
            child: Text(
              arabic
                  ? 'إعادة مراجعة طلب الحذف المحفوظ'
                  : 'Retry saved deletion check',
            ),
          ),
        ),
      );
    }
    if (!_splashReadable || !_assetsPreloaded || !_deletionChecked) {
      return LoadingScreen(
        progressStream: ref.read(assetPreloaderServiceProvider).loadProgress,
      );
    }

    if (_hasDeletionReceipt) return const AccountDeletionScreen();

    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          return const AccountBirthDateGate(child: HomeScreen());
        }
        return const AuthScreen();
      },
      loading: () => LoadingScreen(
        progressStream: ref.read(assetPreloaderServiceProvider).loadProgress,
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(child: Text(ErrorHandler.getAuthErrorMessage(error))),
      ),
    );
  }
}
