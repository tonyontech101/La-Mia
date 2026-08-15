import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'pressable_scale.dart';

/// Outlined "Continue/Sign up with Google" button.
///
/// The Google "G" is drawn with a [CustomPainter] so no network/logo asset is
/// required for this front-end-only build.
class GoogleButton extends StatelessWidget {
  const GoogleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  static const double _height = 52;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _height,
      child: PressableScale(
        pressedScale: 0.975,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.button),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey<bool>(isLoading),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.secondary,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const _GoogleG(size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            label,
                            style: AppTypography.button(
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleG extends StatelessWidget {
  const _GoogleG({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GoogleGPainter()),
      ),
    );
  }
}

/// Minimal four-color Google "G" glyph.
class _GoogleGPainter extends CustomPainter {
  static const Color _blue = Color(0xFF4285F4);
  static const Color _red = Color(0xFFEA4335);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.22;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final arcRect = rect.deflate(stroke / 2);

    // Red: top arc.
    paint.color = _red;
    canvas.drawArc(arcRect, _deg(-45), _deg(-90), false, paint);
    // Yellow: left arc.
    paint.color = _yellow;
    canvas.drawArc(arcRect, _deg(-135), _deg(-90), false, paint);
    // Green: bottom arc.
    paint.color = _green;
    canvas.drawArc(arcRect, _deg(135), _deg(-90), false, paint);
    // Blue: right arc + inward crossbar.
    paint.color = _blue;
    canvas.drawArc(arcRect, _deg(45), _deg(-90), false, paint);
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      paint..strokeWidth = stroke,
    );
  }

  double _deg(double degrees) => degrees * 3.1415926535 / 180.0;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
