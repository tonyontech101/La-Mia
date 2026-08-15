import 'package:flutter/material.dart';

/// A row of equal-width tabs whose highlight slides smoothly between tabs.
///
/// Instead of each tab fading its own background in/out in place, a single
/// [highlight] widget is drawn behind the active tab and animates its
/// horizontal position whenever [index] changes — so the selected indicator
/// visibly glides left/right to the tapped tab.
///
/// Tab content is built by [builder] (pass `isActive` to drive a smooth text
/// fade, e.g. via [AnimatedDefaultTextStyle]) and should use a transparent
/// background so [highlight] shows through.
///
/// Honors the system "disable animations" setting by snapping instantly.
class SlidingTabBar extends StatelessWidget {
  const SlidingTabBar({
    super.key,
    required this.index,
    required this.itemCount,
    required this.highlight,
    required this.builder,
    required this.onChanged,
    this.duration = const Duration(milliseconds: 280),
    this.curve = Curves.easeOutCubic,
  });

  /// Index of the currently active tab (drives the highlight position).
  final int index;

  /// Number of tabs, all rendered at equal width.
  final int itemCount;

  /// The widget that is slid underneath the active tab. Shape it like the
  /// active pill (color, radius, shadow).
  final Widget highlight;

  /// Builds the content of a single tab. `isActive` reflects whether tab
  /// [index] is selected.
  final Widget Function(BuildContext context, int index, bool isActive) builder;

  /// Called when a tab is tapped, with that tab's index.
  final ValueChanged<int> onChanged;

  /// How long the highlight glide takes.
  final Duration duration;

  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / itemCount;
        final highlightPositioned = reduceMotion
            ? Positioned(
                left: index * tabWidth,
                width: tabWidth,
                top: 0,
                bottom: 0,
                child: highlight,
              )
            : AnimatedPositioned(
                duration: duration,
                curve: curve,
                left: index * tabWidth,
                width: tabWidth,
                top: 0,
                bottom: 0,
                child: highlight,
              );

        return Stack(
          children: [
            highlightPositioned,
            // Expanded cells already stretch to the full bar height, so no
            // explicit CrossAxisAlignment.stretch is needed here — that would
            // crash inside vertical scroll views, which give unbounded height.
            Row(
              children: [
                for (var i = 0; i < itemCount; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: builder(context, i, i == index),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
