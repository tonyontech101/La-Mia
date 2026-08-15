import 'package:flutter/material.dart';

/// Wraps [child] in a directional slide-and-fade whenever [index] changes.
///
/// Tab content slides in the direction the user tapped: moving to a higher
/// [index] (a tab further to the right) slides the strip left — new content
/// enters from the right edge while the outgoing content exits to the left —
/// and moving to a lower index slides the other way.
///
/// When the tab index itself hasn't changed but [transitionKey] has (e.g. a
/// loading/error/ready state swap within the same tab), a gentler vertical
/// fade-and-rise is used instead of a horizontal slide.
///
/// Honors the system "disable animations" setting by switching instantly.
class SlideTabSwitcher extends StatefulWidget {
  const SlideTabSwitcher({
    super.key,
    required this.index,
    required this.child,
    this.transitionKey = '',
    this.duration = const Duration(milliseconds: 320),
  });

  /// The currently selected tab index. When it changes, [child] slides in
  /// from the side of the tapped tab.
  final int index;

  /// The content for the current tab.
  final Widget child;

  /// Extra identity for the current content. Change this alongside the same
  /// [index] to re-trigger a transition that fades gently instead of sliding
  /// (used for loading / error / refresh swaps inside a tab).
  final String transitionKey;

  /// How long the transition takes.
  final Duration duration;

  @override
  State<SlideTabSwitcher> createState() => _SlideTabSwitcherState();
}

class _SlideTabSwitcherState extends State<SlideTabSwitcher> {
  late int _previousIndex;
  bool _indexChanged = false;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.index;
  }

  @override
  void didUpdateWidget(covariant SlideTabSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    _indexChanged = widget.index != oldWidget.index;
    if (_indexChanged) {
      _previousIndex = oldWidget.index;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return widget.child;
    }

    // Tapping a tab further right (higher index) moves the strip left:
    // new content enters from the right edge while the old exits left.
    final movingRight = widget.index > _previousIndex;
    final currentKey = ValueKey<String>(
      '${widget.index}|${widget.transitionKey}',
    );

    return AnimatedSwitcher(
      duration: widget.duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) {
        final isIncoming = child.key == currentKey;
        final Offset begin;
        final Offset end;
        if (_indexChanged) {
          // Real tab switch — slide towards the tapped tab.
          begin = isIncoming ? Offset(movingRight ? 1 : -1, 0) : Offset.zero;
          end = isIncoming ? Offset.zero : Offset(movingRight ? -1 : 1, 0);
        } else {
          // Same-tab state swap — gentle fade and rise.
          begin = const Offset(0, 0.02);
          end = Offset.zero;
        }
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: begin, end: end).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: currentKey, child: widget.child),
    );
  }
}
