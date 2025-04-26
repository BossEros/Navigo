import 'package:flutter/material.dart';

class PulsatingMarkerPainter extends CustomPainter {
  final double radius;
  final Color color;
  final AnimationController controller;

  PulsatingMarkerPainter({
    required this.radius,
    required this.color,
    required this.controller,
  }) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(1 - controller.value)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      radius * (1 + controller.value),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}