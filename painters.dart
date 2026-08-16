import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF0F0F22)
      ..strokeWidth = 0.5;
    const s = 28.0;
    for (double x = 0; x <= size.width; x += s) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += s) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BracketPainter extends CustomPainter {
  final Color color;

  const BracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, size.height), Offset.zero, p);
    canvas.drawLine(Offset.zero, Offset(size.width, 0), p);
  }

  @override
  bool shouldRepaint(covariant BracketPainter oldDelegate) =>
      oldDelegate.color != color;
}
