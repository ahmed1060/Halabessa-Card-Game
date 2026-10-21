import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:halabessa/core/services/asset_preloader_service.dart';
import 'package:halabessa/core/widgets/loading_screen.dart';
import 'package:halabessa/features/auth/domain/models/app_user.dart';
import 'package:halabessa/features/auth/presentation/pages/auth_wrapper.dart';
import 'package:halabessa/features/auth/presentation/providers/auth_providers.dart';

class _Preloader extends AssetPreloaderService {
  final Future<void> ready;
  _Preloader(Ref ref, this.ready) : super(ref);
  @override
  Future<void> preloadAll(BuildContext context) => ready;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Widget app(Future<void> assets) => ProviderScope(
    overrides: [
      assetPreloaderServiceProvider.overrideWith((ref) {
        final service = _Preloader(ref, assets);
        ref.onDispose(service.dispose);
        return service;
      }),
      // A local sentinel proves the handoff; no cloud SDK or account is touched.
      authStateChangesProvider.overrideWith(
        (ref) => Stream<AppUser?>.error(StateError('local-auth-sentinel')),
      ),
    ],
    child: const MaterialApp(home: AuthWrapper()),
  );

  testWidgets('fast assets retain one readable second, then hand off', (
    tester,
  ) async {
    await tester.pumpWidget(app(Future.value()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 999));
    expect(find.byType(LoadingScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byType(LoadingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('the readability beat cannot release unfinished asset loading', (
    tester,
  ) async {
    final assets = Completer<void>();
    await tester.pumpWidget(app(assets.future));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(LoadingScreen), findsOneWidget);
    assets.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LoadingScreen), findsNothing);
  });
  testWidgets('leaving startup cancels its cosmetic timer safely', (
    tester,
  ) async {
    await tester.pumpWidget(app(Future.value()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
