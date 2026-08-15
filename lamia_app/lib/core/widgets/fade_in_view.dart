import 'dart:async';

import 'package:flutter/material.dart';

/// Fades, slides, and gently scales [child] into view when it first appears.
///
/// Use [delay] to stagger lists of cards/rows so they cascade in one by one
/// instead of popping in all at once. Honors the system "disable animations"
/// accessibility setting by rendering instantly.
class FadeInView extends StatefulWidget {
  const FadeInView({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offset = const Offset(0, 18),
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;

  /// Optional stagger delay before the entrance starts.
  final Duration delay;

  /// How long the entrance takes.
  final Duration duration;

  /// Starting offset, sliding towards zero as the child appears.
  final Offset offset;

  final Curve curve;

  @override
  State<FadeInView> createState() => _FadeInViewState();
}

class _FadeInViewState extends State<FadeInView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _position;
  late final Animation<double> _scale;
  Timer? _delayTimer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _position = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(
      curved,
    );
    _scale = Tween<double>(begin: 0.985, end: 1.0).animate(curved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;

    _started = true;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion || widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: _position.value,
            child: Transform.scale(
              scale: _scale.value,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
