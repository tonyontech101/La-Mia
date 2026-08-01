import 'package:flutter/material.dart';
import 'main_navigation_shell.dart';

/// Main home screen delegating to [MainNavigationShell] (Dashboard + Navigation).
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key, this.isGuest = false});

  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    return MainNavigationShell(isGuest: isGuest);
  }
}
