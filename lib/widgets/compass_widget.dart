import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CompassWidget extends StatelessWidget {
  final double heading;

  const CompassWidget({super.key, required this.heading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.85),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.divider),
      ),
      child: Transform.rotate(
        angle: -heading * math.pi / 180,
        child: CustomPaint(painter: _CompassPainter()),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 6;

    // N arrow (red)
    final paintN = Paint()..color = Colors.red..style = PaintingStyle.fill;
    final pathN = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx - 5, cy)
      ..lineTo(cx + 5, cy)
      ..close();
    canvas.drawPath(pathN, paintN);

    // S arrow (white)
    final paintS = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final pathS = Path()
      ..moveTo(cx, cy + r)
      ..lineTo(cx - 5, cy)
      ..lineTo(cx + 5, cy)
      ..close();
    canvas.drawPath(pathS, paintS);

    // N label
    final tp = TextPainter(
      text: const TextSpan(text: 'N', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - r - 12));
  }

  @override
  bool shouldRepaint(_CompassPainter old) => false;
}
