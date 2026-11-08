import 'dart:math' as math;
import 'dart:ui' show FontFeature, PathMetric;

import 'package:flutter/material.dart';

class PadStyle {
  static const Color ink = Color(0xFFB8B8B8);
  static const Color inkBright = Color(0xFFFFFFFF);
  static const Color muted = Color(0x7AB8B8B8);
  static const Color line = Color(0xA6BEBEBE);
  static const Color lineSoft = Color(0x59BEBEBE);
  static const Color press = Color(0x59D4E3F3);
  static const Color pressStrong = Color(0x99D4E3F3);
  static const Color panel = Color(0xF2070A0F);
  static const Color panelSoft = Color(0xD9070A0F);
  static const Color field = Color(0x8C04070A);
  static const Color ok = Color(0xFF46D585);
  static const Color bad = Color(0xFFFF6B6B);
  static const Color warn = Color(0xFFE3C567);

  static TextStyle label({
    double size = 10,
    double spacing = 1.6,
    FontWeight weight = FontWeight.w700,
    Color color = ink,
  }) => TextStyle(
    fontSize: size,
    letterSpacing: spacing,
    fontWeight: weight,
    color: color,
    height: 1.1,
  );

  static TextStyle numeric({
    double size = 11,
    FontWeight weight = FontWeight.w600,
    Color color = ink,
  }) => TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );
}

class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.4,
    this.dash = 6,
    this.gap = 4,
    this.radius = 4,
  });

  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final Path path = Path()..addRRect(rrect);
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap;
}

class ShoulderPainter extends CustomPainter {
  const ShoulderPainter({required this.isLeft, required this.fill});

  final bool isLeft;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final List<Offset> points = isLeft
        ? <Offset>[
            Offset(w * 0.18, h * 0.05),
            Offset(w * 0.96, h * 0.05),
            Offset(w * 0.96, h * 0.95),
            Offset(w * 0.05, h * 0.95),
          ]
        : <Offset>[
            Offset(w * 0.04, h * 0.05),
            Offset(w * 0.82, h * 0.05),
            Offset(w * 0.95, h * 0.95),
            Offset(w * 0.04, h * 0.95),
          ];
    final Path path = Path()..addPolygon(points, true);
    if (fill.a > 0) {
      canvas.drawPath(path, Paint()..color = fill);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = PadStyle.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(ShoulderPainter oldDelegate) =>
      oldDelegate.isLeft != isLeft || oldDelegate.fill != fill;
}

class DpadPainter extends CustomPainter {
  const DpadPainter({required this.x, required this.y, required this.spread});

  final int x;
  final int y;
  final double spread;

  @override
  void paint(Canvas canvas, Size size) {
    final double cell = size.shortestSide / 3;
    final double offset = spread / 100 * cell;
    final double inset = cell * 0.055;
    final double radius = cell * 0.08;

    void cap(int col, int row, Offset shift, bool active) {
      final Rect rect = Rect.fromLTWH(
        col * cell + inset + shift.dx,
        row * cell + inset + shift.dy,
        cell - inset * 2,
        cell - inset * 2,
      );
      final RRect rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(radius),
      );
      if (active) {
        canvas.drawRRect(rrect, Paint()..color = PadStyle.press);
      }
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = PadStyle.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    }

    cap(1, 0, Offset(0, -offset), y < 0);
    cap(2, 1, Offset(offset, 0), x > 0);
    cap(1, 2, Offset(0, offset), y > 0);
    cap(0, 1, Offset(-offset, 0), x < 0);

    final Rect hub = Rect.fromLTWH(
      cell + cell * 0.1,
      cell + cell * 0.1,
      cell * 0.8,
      cell * 0.8,
    );
    canvas.drawRect(
      hub,
      Paint()
        ..color = PadStyle.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );

    void chevron(
      int col,
      int row,
      Offset shift,
      String direction,
      bool active,
    ) {
      final Offset center = Offset(
        col * cell + cell / 2 + shift.dx,
        row * cell + cell / 2 + shift.dy,
      );
      final double s = cell * 0.17;
      final Path path = Path();
      switch (direction) {
        case 'up':
          path
            ..moveTo(center.dx - s, center.dy + s * 0.55)
            ..lineTo(center.dx, center.dy - s * 0.55)
            ..lineTo(center.dx + s, center.dy + s * 0.55);
        case 'down':
          path
            ..moveTo(center.dx - s, center.dy - s * 0.55)
            ..lineTo(center.dx, center.dy + s * 0.55)
            ..lineTo(center.dx + s, center.dy - s * 0.55);
        case 'left':
          path
            ..moveTo(center.dx + s * 0.55, center.dy - s)
            ..lineTo(center.dx - s * 0.55, center.dy)
            ..lineTo(center.dx + s * 0.55, center.dy + s);
        default:
          path
            ..moveTo(center.dx - s * 0.55, center.dy - s)
            ..lineTo(center.dx + s * 0.55, center.dy)
            ..lineTo(center.dx - s * 0.55, center.dy + s);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = active ? PadStyle.inkBright : PadStyle.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    chevron(1, 0, Offset(0, -offset), 'up', y < 0);
    chevron(2, 1, Offset(offset, 0), 'right', x > 0);
    chevron(1, 2, Offset(0, offset), 'down', y > 0);
    chevron(0, 1, Offset(-offset, 0), 'left', x < 0);
  }

  @override
  bool shouldRepaint(DpadPainter oldDelegate) =>
      oldDelegate.x != x || oldDelegate.y != y || oldDelegate.spread != spread;
}

enum FaceSymbol { triangle, circle, cross, square }

class FaceSymbolPainter extends CustomPainter {
  const FaceSymbolPainter({required this.symbol, required this.color});

  final FaceSymbol symbol;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (symbol) {
      case FaceSymbol.triangle:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.5, h * 0.2)
            ..lineTo(w * 0.842, h * 0.8)
            ..lineTo(w * 0.158, h * 0.8)
            ..close(),
          paint,
        );
      case FaceSymbol.circle:
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.317, paint);
      case FaceSymbol.cross:
        canvas
          ..drawLine(
            Offset(w * 0.275, h * 0.275),
            Offset(w * 0.725, h * 0.725),
            paint,
          )
          ..drawLine(
            Offset(w * 0.725, h * 0.275),
            Offset(w * 0.275, h * 0.725),
            paint,
          );
      case FaceSymbol.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.221, h * 0.221, w * 0.558, h * 0.558),
            Radius.circular(w * 0.046),
          ),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(FaceSymbolPainter oldDelegate) =>
      oldDelegate.symbol != symbol || oldDelegate.color != color;
}

class StickBasePainter extends CustomPainter {
  const StickBasePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.shortestSide / 2 - 1.4;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      radius,
      Paint()
        ..color = PadStyle.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6,
    );
    final double inset = size.shortestSide * 0.032;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      radius - inset,
      Paint()
        ..color = PadStyle.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(StickBasePainter oldDelegate) => false;
}

class KnobPainter extends CustomPainter {
  const KnobPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.shortestSide / 2;
    canvas.drawCircle(center, radius, Paint()..color = const Color(0x5904070A));
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius - 1)),
    );
    final Paint dot = Paint()..color = const Color(0x8CBEBEBE);
    const double step = 4;
    for (double y = 0; y <= size.height; y += step) {
      for (double x = 0; x <= size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1, dot);
      }
    }
    canvas.restore();
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..color = PadStyle.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(KnobPainter oldDelegate) => false;
}
