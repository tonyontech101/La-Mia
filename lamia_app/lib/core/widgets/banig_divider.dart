import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// The app's recurring signature ornament — a woven banig (palm-mat) hairline.
/// Appears once per major surface as a quiet structural divider.
class BanigDivider extends StatelessWidget {
  const BanigDivider({super.key, this.height = 14, this.opacity = 0.45});

  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _BanigWeavePainter(opacity: opacity),
      ),
    );
  }
}

class _BanigWeavePainter extends CustomPainter {
  const _BanigWeavePainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = AppColors.border.withValues(alpha: opacity)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final knotPaint = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: opacity * 0.6)
      ..style = PaintingStyle.fill;

    const cellW = 6.0;
    const cellH = 5.0;
    final cols = (size.width / cellW).ceil();

    for (var row = 0; row < 2; row++) {
      final y = row * cellH;
      for (var col = 0; col < cols; col++) {
        final x = col * cellW;
        final rect = Rect.fromLTWH(x, y, cellW, cellH);
        canvas.drawRect(rect, strokePaint);

        if (col % 4 == 0 && row == (col ~/ 4) % 2) {
          canvas.drawCircle(
            Offset(x + cellW / 2, y + cellH / 2),
            1.2,
            knotPaint,
          );
        }
      }
    }

    canvas.drawLine(
      Offset(0, cellH),
      Offset(size.width, cellH),
      Paint()
        ..color = AppColors.border.withValues(alpha: opacity * 0.7)
        ..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(covariant _BanigWeavePainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
