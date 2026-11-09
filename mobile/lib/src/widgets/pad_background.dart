import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

const List<int> kPadBackgroundColors = <int>[
  0xFF000000,
  0xFF070A0F,
  0xFF0B1118,
  0xFF10161D,
  0xFF0D1411,
  0xFF171012,
  0xFF121018,
  0xFF1A1510,
];

class PadBackground extends StatelessWidget {
  const PadBackground({
    super.key,
    required this.color,
    required this.imagePath,
    required this.dim,
  });

  final int color;
  final String imagePath;
  final double dim;

  @override
  Widget build(BuildContext context) {
    final bool hasImage = imagePath.isNotEmpty && File(imagePath).existsSync();
    return ColoredBox(
      color: Color(color),
      child: hasImage
          ? Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  cacheWidth: 1920,
                  gaplessPlayback: true,
                  errorBuilder:
                      (BuildContext context, Object error, StackTrace? stack) {
                        return const SizedBox.shrink();
                      },
                ),
                ColoredBox(
                  color: Color.fromRGBO(
                    0,
                    0,
                    0,
                    dim.clamp(0.0, 0.9).toDouble(),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}

class BrandWatermark extends StatelessWidget {
  const BrandWatermark({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(painter: _BrandWatermarkPainter()),
    );
  }
}

class _BrandWatermarkPainter extends CustomPainter {
  const _BrandWatermarkPainter();

  static const String _text = 'Boy Alone';

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final double targetWidth = size.width * 0.78;
    double fontSize = math.min(size.height * 0.3, 112);

    TextPainter layout(Paint paint) {
      return TextPainter(
        text: TextSpan(
          text: _text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: fontSize * 0.045,
            height: 1,
            foreground: paint,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
    }

    Paint stroke(Color color, double width) {
      return Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..color = color;
    }

    TextPainter sample = layout(stroke(PadStyle.ink, 1));
    if (sample.width > targetWidth) {
      fontSize *= targetWidth / sample.width;
    }
    final double lightWidth = (fontSize * 0.032).clamp(1.1, 2.6);
    final double darkWidth = (fontSize * 0.085).clamp(2.2, 6.4);
    final TextPainter light = layout(
      stroke(const Color(0x8CB8B8B8), lightWidth),
    );
    final TextPainter dark = layout(stroke(const Color(0xB3000000), darkWidth));
    final Offset offset = Offset(
      (size.width - light.width) / 2,
      (size.height - light.height) / 2,
    );
    dark.paint(canvas, offset);
    light.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_BrandWatermarkPainter oldDelegate) => false;
}
