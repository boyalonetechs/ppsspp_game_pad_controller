import 'package:flutter/material.dart';

import '../protocol.dart';
import '../theme.dart';
import '../transport.dart';
import 'icons.dart';
import 'press_button.dart';

class ActionBar extends StatelessWidget {
  const ActionBar({
    super.key,
    required this.link,
    required this.haptics,
    required this.releaseToken,
  });

  final PadLink link;
  final bool haptics;
  final int releaseToken;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _iconButton(PadButton.l3, PadIcons.ff, 'Fast forward'),
        const SizedBox(width: 10),
        _menuButton(),
        const SizedBox(width: 10),
        _iconButton(PadButton.r3, PadIcons.rew, 'Rewind'),
        const SizedBox(width: 16),
        _pillButton(PadButton.select, 'SELECT', 76),
        const SizedBox(width: 10),
        _pillButton(PadButton.start, 'START', 72),
      ],
    );
  }

  Widget _iconButton(PadButton button, String icon, String label) {
    return PressButton(
      semanticLabel: label,
      releaseToken: releaseToken,
      haptics: haptics,
      pressedScale: 1.1,
      heldScale: 1.18,
      onDown: () => link.button(button, true),
      onUp: () => link.button(button, false),
      builder: (BuildContext context, bool pressed, bool held) {
        return Container(
          width: 46,
          height: 32,
          decoration: _decoration(pressed),
          alignment: Alignment.center,
          child: PadIcon(
            icon,
            size: 14,
            color: pressed ? PadStyle.inkBright : PadStyle.ink,
          ),
        );
      },
    );
  }

  Widget _menuButton() {
    return PressButton(
      semanticLabel: 'Menu',
      releaseToken: releaseToken,
      haptics: haptics,
      pressedScale: 1.1,
      heldScale: 1.18,
      onDown: () => link.button(PadButton.guide, true),
      onUp: () => link.button(PadButton.guide, false),
      builder: (BuildContext context, bool pressed, bool held) {
        return Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: pressed ? PadStyle.press : Colors.transparent,
            border: Border.all(
              color: pressed ? PadStyle.ink : PadStyle.line,
              width: PadStyle.controlStroke,
            ),
          ),
          alignment: Alignment.center,
          child: SizedBox(
            width: 13,
            height: 13,
            child: CustomPaint(
              painter: FaceSymbolPainter(
                symbol: FaceSymbol.triangle,
                color: pressed ? PadStyle.inkBright : PadStyle.ink,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pillButton(PadButton button, String label, double width) {
    return PressButton(
      semanticLabel: label,
      releaseToken: releaseToken,
      haptics: haptics,
      pressedScale: 1.08,
      heldScale: 1.14,
      onDown: () => link.button(button, true),
      onUp: () => link.button(button, false),
      builder: (BuildContext context, bool pressed, bool held) {
        return Container(
          width: width,
          height: 32,
          decoration: _decoration(pressed),
          alignment: Alignment.center,
          child: Text(
            label,
            style: PadStyle.label(
              size: 9,
              spacing: 1.4,
              color: pressed ? PadStyle.inkBright : PadStyle.ink,
            ),
          ),
        );
      },
    );
  }

  BoxDecoration _decoration(bool pressed) => BoxDecoration(
    borderRadius: BorderRadius.circular(2),
    color: pressed ? PadStyle.press : const Color(0x3304070A),
    border: Border.all(
      color: pressed ? PadStyle.ink : PadStyle.line,
      width: PadStyle.controlStroke,
    ),
  );
}
