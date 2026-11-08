import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_state.dart';
import '../layout.dart';
import '../theme.dart';
import '../transport.dart';
import '../widgets/action_bar.dart';
import '../widgets/analog_stick.dart';
import '../widgets/control_group.dart';
import '../widgets/dpad.dart';
import '../widgets/face_pad.dart';
import '../widgets/icons.dart';
import '../widgets/shoulder.dart';
import 'settings_sheet.dart';

class PadScreen extends StatefulWidget {
  const PadScreen({
    super.key,
    required this.app,
    required this.onOpenConnection,
  });

  final AppState app;
  final VoidCallback onOpenConnection;

  @override
  State<PadScreen> createState() => _PadScreenState();
}

class _PadScreenState extends State<PadScreen> with WidgetsBindingObserver {
  late final Listenable _merged = Listenable.merge(<Listenable>[
    widget.app,
    widget.app.link,
  ]);
  String? _toast;
  Timer? _toastTimer;
  bool _editCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable().ignore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _toastTimer?.cancel();
    WakelockPlus.disable().ignore();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      widget.app.releaseAll();
    }
    if (state == AppLifecycleState.resumed) {
      WakelockPlus.enable().ignore();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _showToast(String text) {
    _toastTimer?.cancel();
    setState(() => _toast = text);
    _toastTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _openSettings() {
    showControlSettings(
      context,
      widget.app,
      onEdit: () {
        widget.app.setEditing(true);
        _showToast('Drag to move · pinch or slider to resize');
      },
    );
  }

  void _finishEditing() {
    widget.app.setEditing(false);
    widget.app.persistLayout();
    _showToast('Layout saved');
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.viewPaddingOf(context);
    return ListenableBuilder(
      listenable: _merged,
      builder: (BuildContext context, Widget? _) {
        final Size size = MediaQuery.sizeOf(context);
        final AppState app = widget.app;
        final bool editing = app.editing;
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              _group(
                app,
                PadGroup.l,
                _baseRect(PadGroup.l, size, safe),
                ShoulderButton(
                  isLeft: true,
                  link: app.link,
                  haptics: app.settings.haptics,
                  releaseToken: app.releaseToken,
                ),
              ),
              _group(
                app,
                PadGroup.r,
                _baseRect(PadGroup.r, size, safe),
                ShoulderButton(
                  isLeft: false,
                  link: app.link,
                  haptics: app.settings.haptics,
                  releaseToken: app.releaseToken,
                ),
              ),
              _group(
                app,
                PadGroup.dpad,
                _baseRect(PadGroup.dpad, size, safe),
                DPad(
                  spread: app.layout.groups[PadGroup.dpad]!.spread,
                  releaseToken: app.releaseToken,
                  onChanged: app.link.hat,
                ),
              ),
              _group(
                app,
                PadGroup.stick,
                _baseRect(PadGroup.stick, size, safe),
                AnalogStick(
                  deadzone: app.settings.deadzone,
                  releaseToken: app.releaseToken,
                  onChanged: app.link.axis,
                ),
              ),
              _group(
                app,
                PadGroup.face,
                _baseRect(PadGroup.face, size, safe),
                FacePad(
                  link: app.link,
                  spread: app.layout.groups[PadGroup.face]!.spread,
                  haptics: app.settings.haptics,
                  releaseToken: app.releaseToken,
                ),
              ),
              _group(
                app,
                PadGroup.center,
                _baseRect(PadGroup.center, size, safe),
                Center(
                  child: ActionBar(
                    link: app.link,
                    haptics: app.settings.haptics,
                    releaseToken: app.releaseToken,
                  ),
                ),
              ),
              if (!editing) _bottomBar(safe),
              if (editing) _editBar(context, safe, size),
              if (_toast != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: safe.bottom + 54,
                  child: Center(
                    child: IgnorePointer(child: _toastView(_toast!)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _group(AppState app, PadGroup group, Rect base, Widget child) {
    final GroupLayout value = app.layout.groups[group]!;
    final double scale = app.layout.effectiveScale(group);
    final Rect rect = Rect.fromCenter(
      center: base.center + Offset(value.dx, value.dy),
      width: base.width * scale,
      height: base.height * scale,
    );
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: base.width,
          height: base.height,
          child: ControlGroup(
            app: app,
            group: group,
            editing: app.editing,
            selected: app.selectedGroup == group,
            child: child,
          ),
        ),
      ),
    );
  }

  Rect _baseRect(PadGroup group, Size size, EdgeInsets safe) {
    final double vmin = math.min(size.width, size.height);
    double clampValue(double value, double low, double high) =>
        value.clamp(low, high).toDouble();
    switch (group) {
      case PadGroup.dpad:
        final double side = clampValue(vmin * 0.38, 110, 180);
        return Rect.fromLTWH(
          safe.left + size.width * 0.24,
          size.height - safe.bottom - side - 44,
          side,
          side,
        );
      case PadGroup.stick:
        final double side = clampValue(vmin * 0.25, 90, 155);
        return Rect.fromLTWH(
          safe.left + size.width * 0.065,
          size.height - safe.bottom - size.height * 0.215 - side,
          side,
          side,
        );
      case PadGroup.face:
        final double side = clampValue(vmin * 0.5, 160, 225);
        return Rect.fromLTWH(
          size.width - safe.right - size.width * 0.055 - side,
          size.height - safe.bottom - size.height * 0.18 - side,
          side,
          side,
        );
      case PadGroup.l:
        final double width = clampValue(size.width * 0.13, 92, 180);
        final double height = clampValue(vmin * 0.0792, 29.7, 55.44);
        return Rect.fromLTWH(safe.left + 18, safe.top + 12, width, height);
      case PadGroup.r:
        final double width = clampValue(size.width * 0.13, 92, 180);
        final double height = clampValue(vmin * 0.0792, 29.7, 55.44);
        return Rect.fromLTWH(
          size.width - safe.right - 18 - width,
          safe.top + 12,
          width,
          height,
        );
      case PadGroup.center:
        const double width = 340;
        return Rect.fromLTWH((size.width - width) / 2, safe.top + 8, width, 40);
    }
  }

  Widget _bottomBar(EdgeInsets safe) {
    final PadLink link = widget.app.link;
    final String text;
    final Color color;
    switch (link.status) {
      case LinkStatus.idle:
        text = 'not connected';
        color = PadStyle.muted;
      case LinkStatus.connecting:
        text = 'connecting';
        color = PadStyle.warn;
      case LinkStatus.connected:
        text = 'connected · ${link.rttMs} ms';
        color = PadStyle.ok;
      case LinkStatus.offline:
        text = 'offline · retrying';
        color = PadStyle.bad;
    }
    return Positioned(
      left: 0,
      right: 0,
      bottom: safe.bottom + 8,
      child: Center(
        child: Opacity(
          opacity: 0.72,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              GestureDetector(
                onTap: widget.onOpenConnection,
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: const Color(0x8C000000),
                    border: Border.all(color: PadStyle.lineSoft, width: 1.6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: <BoxShadow>[
                            BoxShadow(color: color, blurRadius: 6),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(text, style: PadStyle.label(size: 9)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _smallIconButton(
                icon: PadIcons.edit,
                label: 'Edit layout',
                onTap: () {
                  widget.app.setEditing(true);
                  _showToast('Drag to move · pinch or slider to resize');
                },
              ),
              const SizedBox(width: 8),
              _smallIconButton(
                icon: PadIcons.gear,
                label: 'Settings',
                onTap: _openSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallIconButton({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: const Color(0x6604070A),
            border: Border.all(color: PadStyle.line, width: 2.2),
          ),
          alignment: Alignment.center,
          child: PadIcon(icon, size: 13),
        ),
      ),
    );
  }

  Widget _editBar(BuildContext context, EdgeInsets safe, Size size) {
    final AppState app = widget.app;
    final PadGroup selected = app.selectedGroup;
    final GroupLayout value = app.layout.groups[selected]!;
    final double width = math.min(520, size.width * 0.62);
    return Positioned(
      left: (size.width - width) / 2,
      top: safe.top + 8,
      width: width,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: PadStyle.panel,
          border: Border.all(color: PadStyle.line, width: 1.8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'EDIT LAYOUT',
                  style: PadStyle.label(size: 10, spacing: 1.6),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _editCollapsed
                        ? 'expand to adjust'
                        : 'drag · pinch · tap to select',
                    overflow: TextOverflow.ellipsis,
                    style: PadStyle.label(
                      size: 9,
                      spacing: 0.4,
                      weight: FontWeight.w500,
                      color: PadStyle.muted,
                    ),
                  ),
                ),
                _editTextButton(
                  _editCollapsed ? 'EXPAND' : 'HIDE',
                  () => setState(() => _editCollapsed = !_editCollapsed),
                ),
                const SizedBox(width: 6),
                _editTextButton('RESET', () {
                  app.resetLayout();
                  _showToast('Layout reset');
                }),
                const SizedBox(width: 6),
                _editTextButton('DONE', _finishEditing, primary: true),
              ],
            ),
            if (!_editCollapsed) ...<Widget>[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    for (final PadGroup group in PadGroup.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _groupChip(group, app),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  SizedBox(
                    width: 96,
                    child: Text(
                      selected.label.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: PadStyle.label(size: 9, spacing: 1.1),
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: _sliderTheme(context),
                      child: Slider(
                        min: 30,
                        max: selected.maxScale * 100,
                        value: (value.scale * 100).clamp(
                          30,
                          selected.maxScale * 100,
                        ),
                        onChanged: (double v) =>
                            app.setGroupScale(selected, v / 100),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${(value.scale * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: PadStyle.numeric(size: 10, color: PadStyle.muted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _nudge(app, selected, -12, 0),
                  _nudge(app, selected, 12, 0),
                  _nudge(app, selected, 0, -12),
                  _nudge(app, selected, 0, 12),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _groupChip(PadGroup group, AppState app) {
    final bool selected = app.selectedGroup == group;
    return GestureDetector(
      onTap: () => app.selectGroup(group),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: selected ? PadStyle.press : Colors.transparent,
          border: Border.all(
            color: selected ? PadStyle.ink : PadStyle.lineSoft,
            width: 1.6,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          group.shortLabel,
          style: PadStyle.label(
            size: 8,
            spacing: 1.2,
            color: selected ? PadStyle.inkBright : PadStyle.ink,
          ),
        ),
      ),
    );
  }

  Widget _editTextButton(
    String label,
    VoidCallback onTap, {
    bool primary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: primary ? PadStyle.press : Colors.transparent,
          border: Border.all(
            color: primary ? PadStyle.ink : PadStyle.line,
            width: 1.6,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: PadStyle.label(
            size: 8,
            spacing: 1.2,
            color: primary ? PadStyle.inkBright : PadStyle.ink,
          ),
        ),
      ),
    );
  }

  Widget _nudge(AppState app, PadGroup group, double dx, double dy) {
    final String label = dx < 0
        ? 'LEFT'
        : dx > 0
        ? 'RIGHT'
        : dy < 0
        ? 'UP'
        : 'DOWN';
    return GestureDetector(
      onTap: () {
        final GroupLayout value = app.layout.groups[group]!;
        app.updateGroup(
          group,
          dx: value.dx + dx,
          dy: value.dy + dy,
          persist: true,
        );
      },
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.only(left: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: PadStyle.lineSoft, width: 1.2),
        ),
        alignment: Alignment.center,
        child: Text(
          label.substring(0, 1),
          style: PadStyle.label(size: 8, spacing: 0, color: PadStyle.muted),
        ),
      ),
    );
  }

  Widget _toastView(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: PadStyle.panelSoft,
        border: Border.all(color: PadStyle.lineSoft, width: 1.2),
      ),
      child: Text(
        text,
        style: PadStyle.label(
          size: 9,
          spacing: 0.5,
          weight: FontWeight.w500,
          color: PadStyle.ink,
        ),
      ),
    );
  }
}

SliderThemeData _sliderTheme(BuildContext context) {
  return SliderTheme.of(context).copyWith(
    trackHeight: 2,
    activeTrackColor: PadStyle.ink,
    inactiveTrackColor: PadStyle.lineSoft,
    thumbColor: PadStyle.ink,
    overlayColor: const Color(0x33D4E3F3),
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
  );
}
