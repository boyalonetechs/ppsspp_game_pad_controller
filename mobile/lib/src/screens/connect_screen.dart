import 'package:flutter/material.dart';

import '../app_state.dart';
import '../protocol.dart';
import '../theme.dart';
import '../transport.dart';
import '../widgets/icons.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({
    super.key,
    required this.app,
    required this.onConnected,
    this.autoConnect = false,
  });

  final AppState app;
  final VoidCallback onConnected;
  final bool autoConnect;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  final FocusNode _hostFocus = FocusNode();
  final FocusNode _portFocus = FocusNode();
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _host = TextEditingController(text: widget.app.settings.host);
    _port = TextEditingController(text: widget.app.settings.port.toString());
    widget.app.link.addListener(_onLinkChanged);
    if (widget.autoConnect && _host.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
    }
  }

  @override
  void dispose() {
    widget.app.link.removeListener(_onLinkChanged);
    _host.dispose();
    _port.dispose();
    _hostFocus.dispose();
    _portFocus.dispose();
    super.dispose();
  }

  void _onLinkChanged() {
    if (!mounted || _busy) return;
    if (widget.app.link.status == LinkStatus.connected) widget.onConnected();
  }

  Future<void> _connect() async {
    if (_busy) return;
    final String host = _host.text.trim();
    final int port = int.tryParse(_port.text.trim()) ?? kDefaultPort;
    if (host.isEmpty) {
      setState(() => _error = 'Enter the laptop address');
      _hostFocus.requestFocus();
      return;
    }
    if (port < 1 || port > 65535) {
      setState(() => _error = 'Port must be between 1 and 65535');
      _portFocus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = '';
    });
    final bool ok = await widget.app.connect(host, port);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      widget.onConnected();
    } else {
      setState(() {
        _error = widget.app.link.error.isEmpty
            ? 'No response. Check the laptop address, port and Wi-Fi.'
            : widget.app.link.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.viewPaddingOf(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        minimum: EdgeInsets.only(
          left: safe.left + 20,
          right: safe.right + 20,
          top: safe.top + 16,
          bottom: safe.bottom + 14,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 940),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool wide = constraints.maxWidth > 700;
                  final Widget brand = _brand();
                  final Widget card = _card(context);
                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        brand,
                        const SizedBox(height: 20),
                        card,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(flex: 5, child: brand),
                      const SizedBox(width: 36),
                      Expanded(flex: 4, child: card),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: PadStyle.line, width: 2.4),
                color: const Color(0x3304070A),
              ),
              alignment: Alignment.center,
              child: const PadIcon(PadIcons.gamepad, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'PSP PHONE PAD',
                    style: PadStyle.label(
                      size: 19,
                      spacing: 4.6,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'WIRELESS CONTROLLER',
                    style: PadStyle.label(
                      size: 9,
                      spacing: 2.8,
                      weight: FontWeight.w600,
                      color: PadStyle.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(height: 1, color: PadStyle.lineSoft),
        const SizedBox(height: 16),
        Text(
          'Your laptop runs PPSSPP. This phone becomes the pad and sends '
          'button and stick state over your local network.',
          style: PadStyle.label(
            size: 11,
            spacing: 0.1,
            weight: FontWeight.w500,
            color: PadStyle.ink,
          ),
        ),
        const SizedBox(height: 16),
        _hint(
          PadIcons.wifi,
          'WI-FI',
          'Join the same network as the laptop. 5 GHz gives the cleanest link.',
        ),
        _hint(
          PadIcons.usb,
          'ANDROID USB',
          'Enable USB tethering and use the laptop\'s 192.168.42.x address.',
        ),
        _hint(
          PadIcons.link,
          'IPHONE',
          'Wi-Fi only. Accept the Local Network prompt on first connect.',
        ),
        const SizedBox(height: 6),
        Text(
          'Enter the address printed by ./start.sh on the laptop.',
          style: PadStyle.label(
            size: 9,
            spacing: 0.2,
            weight: FontWeight.w500,
            color: PadStyle.muted,
          ),
        ),
      ],
    );
  }

  Widget _hint(String icon, String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: PadIcon(icon, size: 15, color: PadStyle.muted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: PadStyle.label(
                    size: 8,
                    spacing: 1.6,
                    color: PadStyle.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: PadStyle.label(
                    size: 10,
                    spacing: 0.1,
                    weight: FontWeight.w500,
                    color: PadStyle.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: const Color(0xB3070A0F),
        border: Border.all(color: PadStyle.line, width: 1.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'CONNECT',
            style: PadStyle.label(
              size: 10,
              spacing: 2.2,
              color: PadStyle.muted,
            ),
          ),
          const SizedBox(height: 14),
          _fieldLabel('LAPTOP ADDRESS'),
          const SizedBox(height: 6),
          _field(
            controller: _host,
            focus: _hostFocus,
            hint: '192.168.1.20',
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _portFocus.requestFocus(),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(child: _fieldLabel('PORT')),
              SizedBox(
                width: 96,
                child: _field(
                  controller: _port,
                  focus: _portFocus,
                  hint: '8081',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _connect(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _connectButton(),
          const SizedBox(height: 14),
          ListenableBuilder(
            listenable: widget.app.link,
            builder: (BuildContext context, Widget? _) => _statusRow(),
          ),
          if (_error.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _error,
              style: PadStyle.label(
                size: 9,
                spacing: 0.1,
                weight: FontWeight.w500,
                color: PadStyle.bad,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _connectButton() {
    return GestureDetector(
      onTap: _busy ? null : _connect,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: _busy ? PadStyle.press : const Color(0x33D4E3F3),
          border: Border.all(color: PadStyle.ink, width: 2.4),
        ),
        alignment: Alignment.center,
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(PadStyle.ink),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const PadIcon(PadIcons.link, size: 15),
                  const SizedBox(width: 9),
                  Text(
                    'CONNECT',
                    style: PadStyle.label(size: 11, spacing: 2.1),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _statusRow() {
    final PadLink link = widget.app.link;
    final Color color;
    final String text;
    if (_busy || link.status == LinkStatus.connecting) {
      color = PadStyle.warn;
      text = 'Connecting to the laptop';
    } else {
      switch (link.status) {
        case LinkStatus.connected:
          color = PadStyle.ok;
          text = 'Connected · ${link.rttMs} ms round trip';
        case LinkStatus.offline:
          color = PadStyle.bad;
          text = link.error.isEmpty ? 'Not connected' : link.error;
        case LinkStatus.idle:
          color = PadStyle.muted;
          text = 'Ready';
        case LinkStatus.connecting:
          color = PadStyle.warn;
          text = 'Connecting to the laptop';
      }
    }
    return Row(
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: <BoxShadow>[BoxShadow(color: color, blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: PadStyle.label(
              size: 9,
              spacing: 0.3,
              weight: FontWeight.w500,
              color: color == PadStyle.muted ? PadStyle.muted : PadStyle.ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: PadStyle.label(size: 8, spacing: 1.8, color: PadStyle.muted),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required FocusNode focus,
    required String hint,
    required TextInputType keyboardType,
    required TextInputAction textInputAction,
    required ValueChanged<String> onSubmitted,
  }) {
    return TextField(
      controller: controller,
      focusNode: focus,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autocorrect: false,
      enableSuggestions: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      style: PadStyle.numeric(size: 15, color: PadStyle.ink),
      cursorColor: PadStyle.ink,
      cursorWidth: 1.4,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: PadStyle.numeric(size: 14, color: PadStyle.muted),
        filled: true,
        fillColor: PadStyle.field,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: PadStyle.lineSoft, width: 1.6),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: PadStyle.ink, width: 2),
        ),
      ),
    );
  }
}
