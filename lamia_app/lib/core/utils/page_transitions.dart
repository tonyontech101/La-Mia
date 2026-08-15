import 'package:flutter/material.dart';

/// Fluid page transition used by [fadePageRoute] and registered globally via
/// [PageTransitionsTheme] so every `MaterialPageRoute` in the app animates
/// smoothly: the incoming page fades in while gently zooming and rising, so
/// navigation feels continuous instead of abrupt.
class LaMiaPageTransitionsBuilder extends PageTransitionsBuilder {
  const LaMiaPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final primary = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: primary,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.985, end: 1.0).animate(primary),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(primary),
          child: child,
        ),
      ),
    );
  }
}

/// A fade-through route used for transitions between the auth screens, so the
/// shared hero feels continuous. Now matches the app-wide [LaMiaPageTransitionsBuilder]
/// look: fade + slight zoom + rise.
Route<T> fadePageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}
