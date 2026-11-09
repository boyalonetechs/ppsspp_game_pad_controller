import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class AnalogStick extends StatefulWidget {
  const AnalogStick({
    super.key,
    required this.deadzone,
    required this.onChanged,
    required this.releaseToken,
  });

  final double deadzone;
  final void Function(double x, double y) onChanged;
  final int releaseToken;

  @override
  State<AnalogStick> createState() => _AnalogStickState();
}

class _AnalogStickState extends State<AnalogStick> {
  int? _pointer;
  Offset _offset = Offset.zero;
  Size _size = Size.zero;
  bool _engaged = false;

  @override
  void didUpdateWidget(AnalogStick oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.releaseToken != widget.releaseToken && _pointer != null) {
      _pointer = null;
      _reset();
    }
  }

  void _reset() {
    setState(() {
      _offset = Offset.zero;
      _engaged = false;
    });
    widget.onChanged(0, 0);
  }

  void _move(Offset local) {
    if (_size.isEmpty) return;
    final Offset center = Offset(_size.width / 2, _size.height / 2);
    final double max = _size.shortestSide * 0.21;
    Offset delta = local - center;
    final double length = delta.distance;
    if (length > max && length > 0) {
      delta = delta / length * max;
    }
    setState(() => _offset = delta);
    final double nx = delta.dx / max;
    final double ny = delta.dy / max;
    final double magnitude = math.min(1, math.sqrt(nx * nx + ny * ny));
    double ox = 0;
    double oy = 0;
    if (magnitude > widget.deadzone) {
      final double scale =
          (magnitude - widget.deadzone) / (1 - widget.deadzone) / magnitude;
      ox = (nx * scale).clamp(-1.0, 1.0);
      oy = (ny * scale).clamp(-1.0, 1.0);
    }
    widget.onChanged(ox, oy);
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    setState(() => _engaged = true);
    _move(event.localPosition);
  }

  void _moveEvent(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _move(event.localPosition);
  }

  void _up(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _reset();
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
          onPointerMove: _moveEvent,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                const CustomPaint(painter: StickBasePainter()),
                AnimatedContainer(
                  duration: _engaged
                      ? Duration.zero
                      : const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.translationValues(
                    _offset.dx,
                    _offset.dy,
                    0,
                  ),
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.56,
                      heightFactor: 0.56,
                      child: const CustomPaint(painter: KnobPainter()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
