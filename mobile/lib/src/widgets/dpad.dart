import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class DPad extends StatefulWidget {
  const DPad({
    super.key,
    required this.spread,
    required this.onChanged,
    required this.releaseToken,
  });

  final double spread;
  final void Function(int x, int y) onChanged;
  final int releaseToken;

  @override
  State<DPad> createState() => _DPadState();
}

class _DPadState extends State<DPad> {
  int? _pointer;
  int _x = 0;
  int _y = 0;
  Size _size = Size.zero;

  @override
  void didUpdateWidget(DPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.releaseToken != widget.releaseToken && _pointer != null) {
      _pointer = null;
      _set(0, 0);
    }
  }

  void _set(int x, int y) {
    if (x == _x && y == _y) return;
    setState(() {
      _x = x;
      _y = y;
    });
    widget.onChanged(x, y);
  }

  void _update(Offset local) {
    if (_size.isEmpty) return;
    final double halfW = _size.width / 2;
    final double halfH = _size.height / 2;
    final double dx = (local.dx - halfW) / halfW;
    final double dy = (local.dy - halfH) / halfH;
    final double ax = dx.abs();
    final double ay = dy.abs();
    int x = 0;
    int y = 0;
    if (ax > 0.34) x = dx.sign.toInt();
    if (ay > 0.34) y = dy.sign.toInt();
    if (x == 0 && y == 0 && (ax > 0.16 || ay > 0.16)) {
      if (ax > ay) {
        x = dx.sign.toInt();
      } else {
        y = dy.sign.toInt();
      }
    }
    _set(x, y);
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _update(event.localPosition);
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _update(event.localPosition);
  }

  void _up(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _set(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _size = Size(
          math.max(1, constraints.maxWidth),
          math.max(1, constraints.maxHeight),
        );
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: RepaintBoundary(
            child: CustomPaint(
              size: _size,
              painter: DpadPainter(x: _x, y: _y, spread: widget.spread),
            ),
          ),
        );
      },
    );
  }
}
