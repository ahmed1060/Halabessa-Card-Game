import 'package:flutter/material.dart';

/// Keep the cafe backdrop opaque throughout forward/back navigation.
class LanternPageTransitionsBuilder extends PageTransitionsBuilder {
  const LanternPageTransitionsBuilder();
  @override
  Duration get transitionDuration => const Duration(milliseconds: 230);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 230);
  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return ColoredBox(
      color: const Color(0xFF3B274C),
      child: reduced
          ? child
          : FadeTransition(
              opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
              child: SlideTransition(
                position: animation.drive(
                  Tween(
                    begin: const Offset(0, .025),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutCubic)),
                ),
                child: child,
              ),
            ),
    );
  }
}

const lanternPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: LanternPageTransitionsBuilder(),
    TargetPlatform.iOS: LanternPageTransitionsBuilder(),
    TargetPlatform.macOS: LanternPageTransitionsBuilder(),
    TargetPlatform.windows: LanternPageTransitionsBuilder(),
    TargetPlatform.linux: LanternPageTransitionsBuilder(),
    TargetPlatform.fuchsia: LanternPageTransitionsBuilder(),
  },
);
