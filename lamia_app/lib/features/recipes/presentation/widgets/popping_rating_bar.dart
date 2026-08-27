import 'package:flutter/material.dart';

class PoppingRatingBar extends StatefulWidget {
  final int initialRating;
  final ValueChanged<int> onRatingChanged;
  final double starSize;
  final Color activeColor;
  final Color inactiveColor;

  const PoppingRatingBar({
    super.key,
    required this.initialRating,
    required this.onRatingChanged,
    this.starSize = 32.0,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  State<PoppingRatingBar> createState() => _PoppingRatingBarState();
}

class _PoppingRatingBarState extends State<PoppingRatingBar>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;
  int _currentRating = 0;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
    _controllers = List.generate(5, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
    });

    _scaleAnimations = _controllers.map((controller) {
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.4)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.4, end: 0.95)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.95, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 30,
        ),
      ]).animate(controller);
    }).toList();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleStarTap(int index) {
    final newRating = index + 1;
    setState(() {
      _currentRating = newRating;
    });
    widget.onRatingChanged(newRating);

    // Cascading animation: trigger one after another with a tiny delay
    for (int i = 0; i < 5; i++) {
      if (i < newRating) {
        Future.delayed(Duration(milliseconds: i * 50), () {
          if (mounted) {
            _controllers[i].forward(from: 0.0);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final isFilled = index < _currentRating;
        return ScaleTransition(
          scale: _scaleAnimations[index],
          child: GestureDetector(
            onTap: () => _handleStarTap(index),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                size: widget.starSize,
                color: isFilled ? widget.activeColor : widget.inactiveColor,
              ),
            ),
          ),
        );
      }),
    );
  }
}
