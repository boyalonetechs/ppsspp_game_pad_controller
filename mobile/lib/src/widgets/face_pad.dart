import 'package:flutter/material.dart';

import '../protocol.dart';
import '../theme.dart';
import '../transport.dart';
import 'press_button.dart';

class FacePad extends StatelessWidget {
  const FacePad({
    super.key,
    required this.link,
    required this.spread,
    required this.haptics,
    required this.releaseToken,
  });

  final PadLink link;
  final double spread;
  final bool haptics;
  final int releaseToken;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double side = constraints.biggest.shortestSide;
        final double cell = side / 3;
        final double offset = spread / 100 * cell;
        final double diameter = cell * 0.9;
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            _positioned(
              PadButton.triangle,
              FaceSymbol.triangle,
              Offset(cell * 1.5, cell * 0.5 - offset),
              diameter,
              'Triangle',
            ),
            _positioned(
              PadButton.circle,
              FaceSymbol.circle,
              Offset(cell * 2.5 + offset, cell * 1.5),
              diameter,
              'Circle',
            ),
            _positioned(
              PadButton.cross,
              FaceSymbol.cross,
              Offset(cell * 1.5, cell * 2.5 + offset),
              diameter,
              'Cross',
            ),
            _positioned(
              PadButton.square,
              FaceSymbol.square,
              Offset(cell * 0.5 - offset, cell * 1.5),
              diameter,
              'Square',
            ),
          ],
        );
      },
    );
  }

  Widget _positioned(
    PadButton button,
    FaceSymbol symbol,
    Offset center,
    double diameter,
    String label,
  ) {
    return Positioned(
      left: center.dx - diameter / 2,
      top: center.dy - diameter / 2,
      width: diameter,
      height: diameter,
      child: PressButton(
        semanticLabel: label,
        releaseToken: releaseToken,
        haptics: haptics,
        pressedScale: 1.2,
        heldScale: 1.32,
        onDown: () => link.button(button, true),
        onUp: () => link.button(button, false),
        builder: (BuildContext context, bool pressed, bool held) {
          return DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pressed
                  ? const Color(0x38BEBEBE)
                  : const Color(0x2604070A),
              border: Border.all(
                color: pressed ? PadStyle.ink : PadStyle.line,
                width: 2.4,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(diameter * 0.16),
              child: CustomPaint(
                painter: FaceSymbolPainter(
                  symbol: symbol,
                  color: pressed ? PadStyle.inkBright : PadStyle.ink,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
