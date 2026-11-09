import 'package:flutter/material.dart';

import '../app_state.dart';
import '../layout.dart';
import '../theme.dart';
import '../transport.dart';
import '../widgets/icons.dart';

Future<void> showControlSettings(
  BuildContext context,
  AppState app, {
  required VoidCallback onEdit,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xD9020407),
    builder: (BuildContext dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 620,
            maxHeight: MediaQuery.sizeOf(dialogContext).height - 24,
          ),
          child: _ControlsDialog(
            app: app,
            onClose: () => Navigator.of(dialogContext).pop(),
            onEdit: () {
              Navigator.of(dialogContext).pop();
              onEdit();
            },
          ),
        ),
      );
    },
  );
}

class _ControlsDialog extends StatelessWidget {
  const _ControlsDialog({
    required this.app,
    required this.onClose,
    required this.onEdit,
  });

  final AppState app;
  final VoidCallback onClose;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
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
                'Controls',
                style: PadStyle.label(
                  size: 15,
                  spacing: 0.4,
                  weight: FontWeight.w700,
                  color: PadStyle.ink,
                ),
              ),
              const Spacer(),
              _IconAction(icon: PadIcons.close, label: 'Close', onTap: onClose),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Sizes are saved on this phone. Open Edit layout to drag controls '
            'and pinch to resize.',
            style: PadStyle.label(
              size: 9,
              spacing: 0.3,
              weight: FontWeight.w500,
              color: PadStyle.muted,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: AnimatedBuilder(
                animation: app,
                builder: (BuildContext context, Widget? _) {
                  return LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final bool wide = constraints.maxWidth > 500;
                          final Widget sizes = _sizes(app);
                          final Widget feel = _feel(app);
                          if (!wide) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                sizes,
                                const SizedBox(height: 14),
                                feel,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(child: sizes),
                              const SizedBox(width: 22),
                              SizedBox(width: 220, child: feel),
                            ],
                          );
                        },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _DialogButton(
                  label: 'Reset layout',
                  icon: PadIcons.reset,
                  onTap: app.resetLayout,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DialogButton(
                  label: 'Edit layout',
                  icon: PadIcons.edit,
                  primary: true,
                  onTap: onEdit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sizes(AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'SIZE',
          style: PadStyle.label(size: 9, spacing: 1.8, color: PadStyle.muted),
        ),
        const SizedBox(height: 8),
        _Sizer(
          label: 'All controls',
          value: app.layout.all * 100,
          min: 60,
          max: 200,
          suffix: '%',
          onChanged: (double v) => app.setAll(v / 100),
        ),
        for (final PadGroup group in PadGroup.values)
          _Sizer(
            label: group.label,
            value: app.layout.groups[group]!.scale * 100,
            min: 30,
            max: group.maxScale * 100,
            suffix: '%',
            onChanged: (double v) => app.setGroupScale(group, v / 100),
          ),
        for (final PadGroup group in PadGroup.values)
          if (group.usesSpread)
            _Sizer(
              label: '${group.label} spacing',
              value: app.layout.groups[group]!.spread,
              min: -30,
              max: 28,
              suffix: '%',
              onChanged: (double v) => app.setSpread(group, v),
            ),
      ],
    );
  }

  Widget _feel(AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'FEEL',
          style: PadStyle.label(size: 9, spacing: 1.8, color: PadStyle.muted),
        ),
        const SizedBox(height: 8),
        _Sizer(
          label: 'Dead zone',
          value: app.settings.deadzone * 100,
          min: 0,
          max: 30,
          divisor: 100,
          suffix: '',
          onChanged: (double v) => app.setDeadzone(v / 100),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Haptics',
                style: PadStyle.label(size: 11, spacing: 0.4),
              ),
            ),
            Switch(
              value: app.settings.haptics,
              onChanged: app.setHaptics,
              activeThumbColor: Colors.black,
              activeTrackColor: PadStyle.ink,
              inactiveThumbColor: PadStyle.muted,
              inactiveTrackColor: PadStyle.lineSoft,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'The laptop runs PPSSPP. This app only sends the pad over UDP.',
          style: PadStyle.label(
            size: 9,
            spacing: 0.2,
            weight: FontWeight.w500,
            color: PadStyle.muted,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'LINK',
          style: PadStyle.label(size: 9, spacing: 1.8, color: PadStyle.muted),
        ),
        const SizedBox(height: 8),
        _LinkDiagnostics(app: app),
      ],
    );
  }
}

class _LinkDiagnostics extends StatelessWidget {
  const _LinkDiagnostics({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app.link,
      builder: (BuildContext context, Widget? _) {
        final PadLink link = app.link;
        final Color color;
        final String state;
        switch (link.status) {
          case LinkStatus.idle:
            color = PadStyle.muted;
            state = 'Idle';
          case LinkStatus.connecting:
            color = PadStyle.warn;
            state = 'Connecting';
          case LinkStatus.connected:
            color = PadStyle.ok;
            state = 'Online';
          case LinkStatus.offline:
            color = PadStyle.bad;
            state = 'No reply';
        }
        return Column(
          children: <Widget>[
            _row(
              'Status',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: color, blurRadius: 5),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(state, style: PadStyle.numeric(size: 10)),
                ],
              ),
            ),
            _row(
              'Round trip',
              Text(
                link.status == LinkStatus.connected ? '${link.rttMs} ms' : '—',
                style: PadStyle.numeric(size: 10),
              ),
            ),
            _row(
              'Send rate',
              Text('${link.pps} pkt/s', style: PadStyle.numeric(size: 10)),
            ),
            _row(
              'Address',
              Flexible(
                child: Text(
                  '${app.settings.host}:${app.settings.port}',
                  overflow: TextOverflow.ellipsis,
                  style: PadStyle.numeric(size: 10, color: PadStyle.muted),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: PadStyle.label(size: 9, spacing: 0.2)),
          ),
          const SizedBox(width: 8),
          value,
        ],
      ),
    );
  }
}

class _Sizer extends StatelessWidget {
  const _Sizer({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.suffix,
    this.divisor = 1,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String suffix;
  final double divisor;

  @override
  Widget build(BuildContext context) {
    final double safeValue = value.clamp(min, max);
    final String output = divisor == 1
        ? '${value.round()}$suffix'
        : (value / 100).toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(label, style: PadStyle.label(size: 10, spacing: 0.2)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                activeTrackColor: PadStyle.ink,
                inactiveTrackColor: PadStyle.lineSoft,
                thumbColor: PadStyle.ink,
                overlayColor: const Color(0x33D4E3F3),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                min: min,
                max: max,
                value: safeValue,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              output,
              textAlign: TextAlign.right,
              style: PadStyle.numeric(size: 10, color: PadStyle.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: PadStyle.line, width: 2.2),
          ),
          alignment: Alignment.center,
          child: PadIcon(icon, size: 12),
        ),
      ),
    );
  }
}

class _DialogButton extends StatefulWidget {
  const _DialogButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final String icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (TapDownDetails _) => setState(() => _pressed = true),
      onTapUp: (TapUpDetails _) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: widget.primary || _pressed
              ? PadStyle.press
              : Colors.transparent,
          border: Border.all(
            color: _pressed || widget.primary ? PadStyle.ink : PadStyle.line,
            width: 2.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            PadIcon(
              widget.icon,
              size: 13,
              color: widget.primary || _pressed
                  ? PadStyle.inkBright
                  : PadStyle.ink,
            ),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: PadStyle.label(
                size: 9,
                spacing: 1.0,
                color: widget.primary || _pressed
                    ? PadStyle.inkBright
                    : PadStyle.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
