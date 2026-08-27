import 'package:flutter/material.dart';

class VerticalPoppingButton extends StatefulWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final int count;
  final VoidCallback onTap;

  const VerticalPoppingButton({
    super.key,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.count,
    required this.onTap,
  });

  @override
  State<VerticalPoppingButton> createState() => _VerticalPoppingButtonState();
}

class _VerticalPoppingButtonState extends State<VerticalPoppingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = TweenSequence<double>([
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
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant VerticalPoppingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _controller.forward(from: 0.0);
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Icon(
                widget.isActive ? widget.activeIcon : widget.inactiveIcon,
                size: 26,
                color:
                    widget.isActive ? widget.activeColor : widget.inactiveColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.count}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    widget.isActive ? widget.activeColor : widget.inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
