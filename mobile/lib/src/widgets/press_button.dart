import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PressButton extends StatefulWidget {
  const PressButton({
    super.key,
    required this.onDown,
    required this.onUp,
    required this.releaseToken,
    required this.haptics,
    this.child,
    this.builder,
    this.pressedScale = 1.22,
    this.heldScale = 1.32,
    this.semanticLabel,
  }) : assert(child != null || builder != null);

  final VoidCallback onDown;
  final VoidCallback onUp;
  final int releaseToken;
  final bool haptics;
  final Widget? child;
  final Widget Function(BuildContext context, bool pressed, bool held)? builder;
  final double pressedScale;
  final double heldScale;
  final String? semanticLabel;

  @override
  State<PressButton> createState() => _PressButtonState();
}

class _PressButtonState extends State<PressButton> {
  final Set<int> _pointers = <int>{};
  Timer? _holdTimer;
  bool _pressed = false;
  bool _held = false;

  @override
  void didUpdateWidget(PressButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.releaseToken != widget.releaseToken && _pressed) {
      _clear();
      widget.onUp();
    }
  }

  void _down(PointerDownEvent event) {
    if (_pointers.isEmpty) {
      setState(() {
        _pressed = true;
        _held = false;
      });
      widget.onDown();
      if (widget.haptics) HapticFeedback.selectionClick();
      _holdTimer?.cancel();
      _holdTimer = Timer(const Duration(milliseconds: 340), () {
        if (!mounted || !_pressed) return;
        setState(() => _held = true);
        if (widget.haptics) HapticFeedback.lightImpact();
      });
    }
    _pointers.add(event.pointer);
  }

  void _up(PointerEvent event) {
    if (!_pointers.remove(event.pointer)) return;
    if (_pointers.isEmpty) {
      _clear();
      widget.onUp();
    }
  }

  void _clear() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (!mounted) return;
    setState(() {
      _pressed = false;
      _held = false;
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget content =
        widget.builder?.call(context, _pressed, _held) ??
        widget.child ??
        const SizedBox.shrink();
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: AnimatedScale(
          scale: _pressed
              ? (_held ? widget.heldScale : widget.pressedScale)
              : 1,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOutCubic,
          child: content,
        ),
      ),
    );
  }
}
