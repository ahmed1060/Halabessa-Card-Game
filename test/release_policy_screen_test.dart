import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:halabessa/core/widgets/release_policy_screen.dart';

void main() {
  for (final policy in ReleasePolicy.values) {
    for (final size in [const Size(320, 568), const Size(844, 390)]) {
      testWidgets(
        '$policy notice loads without authentication and fits $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final bundle = _PolicyBundle(policy);
          await tester.pumpWidget(
            DefaultAssetBundle(
              bundle: bundle,
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: const TextScaler.linear(2),
                  ),
                  child: ReleasePolicyScreen(policy: policy),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              policy == ReleasePolicy.privacy
                  ? 'Halabessa privacy notice'
                  : 'Halabessa rules of use',
            ),
            findsOneWidget,
          );
          expect(find.byType(SelectableText), findsWidgets);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _PolicyBundle extends CachingAssetBundle {
  final ReleasePolicy policy;
  _PolicyBundle(this.policy);
  @override
  Future<String> loadString(String key, {bool cache = true}) {
    if (key == 'assets/legal/${policy.name}.json') {
      return SynchronousFuture(File(key).readAsStringSync());
    }
    return rootBundle.loadString(key, cache: cache);
  }

  @override
  Future<ByteData> load(String key) => rootBundle.load(key);
}
