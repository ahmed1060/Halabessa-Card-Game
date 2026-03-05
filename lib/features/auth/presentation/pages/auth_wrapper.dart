import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_screen.dart';
import '../providers/auth_providers.dart';
import '../../../home/presentation/pages/home_screen.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/services/asset_preloader_service.dart';
import '../../../../core/widgets/loading_screen.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool _assetsPreloaded = false;

  @override
  void initState() {
    super.initState();
    _initAssets();
  }

  Future<void> _initAssets() async {
    final preloader = ref.read(assetPreloaderServiceProvider);
    
    // We wait for the first frame to ensure context is available for preloader
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await preloader.preloadAll(context);
      if (mounted) {
        setState(() => _assetsPreloaded = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_assetsPreloaded) {
      return LoadingScreen(
        progressStream: ref.read(assetPreloaderServiceProvider).loadProgress,
      );
    }

    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          return const HomeScreen();
        }
        return const AuthScreen();
      },
      loading: () => LoadingScreen(
        progressStream: ref.read(assetPreloaderServiceProvider).loadProgress,
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Text(ErrorHandler.getAuthErrorMessage(error)),
        ),
      ),
    );
  }
}
