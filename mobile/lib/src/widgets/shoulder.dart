import 'package:flutter/material.dart';

import '../protocol.dart';
import '../theme.dart';
import '../transport.dart';
import 'press_button.dart';

class ShoulderButton extends StatelessWidget {
  const ShoulderButton({
    super.key,
    required this.isLeft,
    required this.link,
    required this.haptics,
    required this.releaseToken,
  });

  final bool isLeft;
  final PadLink link;
  final bool haptics;
  final int releaseToken;

  @override
  Widget build(BuildContext context) {
    final PadButton button = isLeft ? PadButton.l : PadButton.r;
    return PressButton(
      semanticLabel: isLeft ? 'Left shoulder' : 'Right shoulder',
      releaseToken: releaseToken,
      haptics: haptics,
      pressedScale: 1.08,
      heldScale: 1.14,
      onDown: () => link.button(button, true),
      onUp: () => link.button(button, false),
      builder: (BuildContext context, bool pressed, bool held) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CustomPaint(
              painter: ShoulderPainter(
                isLeft: isLeft,
                fill: pressed ? PadStyle.press : Colors.transparent,
              ),
            ),
            Center(
              child: Text(
                isLeft ? 'L' : 'R',
                style: PadStyle.label(
                  size: 15,
                  spacing: 2.4,
                  weight: FontWeight.w800,
                  color: pressed ? PadStyle.inkBright : PadStyle.ink,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
