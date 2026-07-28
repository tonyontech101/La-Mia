import 'package:flutter/material.dart';

/// A fade-through route used for transitions between the auth screens, so the
/// shared hero feels continuous.
Route<T> fadePageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
