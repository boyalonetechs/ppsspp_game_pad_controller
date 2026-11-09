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
  final Map<int, Offset> _pointers = <int, Offset>{};
  int? _dragPointer;
  Offset _dragStart = Offset.zero;
  double _startDx = 0;
  double _startDy = 0;
  bool _dragging = false;
  bool _pinching = false;
  double _pinchDistance = 1;
  double _pinchWidth = 1;
  double _pinchStartScale = 1;
  double _pinchStartSpread = 0;

  double _distance(Offset first, Offset second) {
    final double value = (first - second).distance;
    return value < 1 ? 1 : value;
  }

  void _pointerDown(PointerDownEvent event) {
    if (_pointers.length >= 2) return;
    _pointers[event.pointer] = event.position;
    widget.app.selectGroup(widget.group);
    if (_pointers.length == 1) {
      final GroupLayout value = widget.app.layout.groups[widget.group]!;
      _dragPointer = event.pointer;
      _dragStart = event.position;
      _startDx = value.dx;
      _startDy = value.dy;
      _dragging = true;
      return;
    }
    final List<Offset> points = _pointers.values.toList(growable: false);
    final GroupLayout value = widget.app.layout.groups[widget.group]!;
    final double width =
        (context.size?.width ?? 1) *
        widget.app.layout.effectiveScale(widget.group);
    _dragging = false;
    _pinching = true;
    _pinchDistance = _distance(points[0], points[1]);
    _pinchWidth = width < 1 ? 1 : width;
    _pinchStartScale = value.scale;
    _pinchStartSpread = value.spread;
  }

  void _pointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    if (_pinching && _pointers.length == 2) {
      final List<Offset> points = _pointers.values.toList(growable: false);
      final double distance = _distance(points[0], points[1]);
      if (widget.group.usesSpread) {
        widget.app.updateGroup(
          widget.group,
          spread:
              _pinchStartSpread +
              ((distance - _pinchDistance) / (_pinchWidth * 2)) * 100,
        );
      } else {
        widget.app.updateGroup(
          widget.group,
          scale: _pinchStartScale * (distance / _pinchDistance),
        );
      }
      return;
    }
    if (!_dragging || event.pointer != _dragPointer) return;
    final Offset delta = event.position - _dragStart;
    widget.app.updateGroup(
      widget.group,
      dx: _startDx + delta.dx,
      dy: _startDy + delta.dy,
    );
  }

  void _pointerUp(PointerEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers.remove(event.pointer);
    if (_pinching) {
      _pinching = false;
      if (_pointers.length == 1) {
        final MapEntry<int, Offset> remaining = _pointers.entries.first;
        final GroupLayout value = widget.app.layout.groups[widget.group]!;
        _dragging = true;
        _dragPointer = remaining.key;
        _dragStart = remaining.value;
        _startDx = value.dx;
        _startDy = value.dy;
        widget.app.persistLayout();
        return;
      }
    }
    if (event.pointer == _dragPointer || _pointers.isEmpty) {
      _dragging = false;
      _dragPointer = null;
      widget.app.persistLayout();
    }
  }

  @override
  void didUpdateWidget(ControlGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.editing || oldWidget.group != widget.group) {
      _pointers.clear();
      _dragging = false;
      _pinching = false;
      _dragPointer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = IgnorePointer(
      ignoring: widget.editing,
      child: widget.child,
    );
    if (!widget.editing) return content;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _pointerDown,
      onPointerMove: _pointerMove,
      onPointerUp: _pointerUp,
      onPointerCancel: _pointerUp,
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
