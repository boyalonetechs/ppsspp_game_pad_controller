import 'package:flutter/material.dart';

import '../app_state.dart';
import '../layout.dart';
import '../theme.dart';

class ControlGroup extends StatefulWidget {
  const ControlGroup({
    super.key,
    required this.app,
    required this.group,
    required this.editing,
    required this.selected,
    required this.child,
  });

  final AppState app;
  final PadGroup group;
  final bool editing;
  final bool selected;
  final Widget child;

  @override
  State<ControlGroup> createState() => _ControlGroupState();
}

class _ControlGroupState extends State<ControlGroup> {
  double _startDx = 0;
  double _startDy = 0;
  double _startScale = 1;
  Offset _startFocal = Offset.zero;
  bool _pinching = false;

  void _start(ScaleStartDetails details) {
    final GroupLayout value = widget.app.layout.groups[widget.group]!;
    _startDx = value.dx;
    _startDy = value.dy;
    _startScale = value.scale;
    _startFocal = details.focalPoint;
    _pinching = false;
    widget.app.selectGroup(widget.group);
  }

  void _update(ScaleUpdateDetails details) {
    if (details.pointerCount >= 2) {
      _pinching = true;
      widget.app.updateGroup(widget.group, scale: _startScale * details.scale);
      return;
    }
    if (_pinching) return;
    final Offset delta = details.focalPoint - _startFocal;
    widget.app.updateGroup(
      widget.group,
      dx: _startDx + delta.dx,
      dy: _startDy + delta.dy,
    );
  }

  void _end(ScaleEndDetails details) {
    widget.app.persistLayout();
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = IgnorePointer(
      ignoring: widget.editing,
      child: widget.child,
    );
    if (!widget.editing) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.app.selectGroup(widget.group),
      onScaleStart: _start,
      onScaleUpdate: _update,
      onScaleEnd: _end,
      child: CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: widget.selected ? PadStyle.ink : PadStyle.lineSoft,
          strokeWidth: widget.selected ? 1.8 : 1.2,
          radius: widget.group == PadGroup.stick ? 200 : 4,
        ),
        child: content,
      ),
    );
  }
}
