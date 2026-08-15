import 'package:flutter/material.dart';

/// Gives any tappable surface a fluid press feedback.
///
/// The child scales down slightly while the finger is down and springs back
/// with a gentle overshoot on release. Press state is tracked with a raw
/// [Listener] (not the gesture arena), so it works even when the child owns
/// its own tap handling (cards, buttons, ink wells, ...).
///
/// Honors the system "disable animations" accessibility setting by rendering
/// statically.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
    this.pressDuration = const Duration(milliseconds: 90),
    this.springBackDuration = const Duration(milliseconds: 240),
  });

  /// The widget to wrap.
  final Widget child;

  /// Optional tap callback. Prefer leaving this null when [child] already
  /// handles taps itself (nested recognizers would compete).
  final VoidCallback? onTap;

  /// Scale applied while the finger is down.
  final double pressedScale;

  /// How long the press-down takes.
  final Duration pressDuration;

  /// How long the spring-back (release) takes.
  final Duration springBackDuration;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  bool get _animationsEnabled =>
      !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final pressVisuals = Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed && _animationsEnabled ? widget.pressedScale : 1.0,
        duration: _pressed ? widget.pressDuration : widget.springBackDuration,
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: widget.child,
      ),
    );

    if (widget.onTap == null) return pressVisuals;

    return GestureDetector(onTap: widget.onTap, child: pressVisuals);
  }
}
