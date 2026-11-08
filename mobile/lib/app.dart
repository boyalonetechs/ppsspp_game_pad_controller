import 'package:flutter/material.dart';

import 'src/app_state.dart';
import 'src/screens/connect_screen.dart';
import 'src/screens/pad_screen.dart';
import 'src/theme.dart';

class PadApp extends StatelessWidget {
  const PadApp({super.key, required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PSP Phone Pad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: PadStyle.ink,
          brightness: Brightness.dark,
          surface: Colors.black,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: PadStyle.ink,
          selectionColor: Color(0x55D4E3F3),
          selectionHandleColor: PadStyle.ink,
        ),
      ),
      home: PadRoot(app: app),
    );
  }
}

class PadRoot extends StatefulWidget {
  const PadRoot({super.key, required this.app});

  final AppState app;

  @override
  State<PadRoot> createState() => _PadRootState();
}

class _PadRootState extends State<PadRoot> {
  bool _showPad = false;
  bool _autoConnect = true;

  void _onConnected() {
    setState(() {
      _showPad = true;
      _autoConnect = false;
    });
  }

  void _openConnection() {
    widget.app.releaseAll();
    widget.app.disconnect();
    setState(() {
      _showPad = false;
      _autoConnect = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _showPad
          ? PadScreen(
              key: const ValueKey<String>('pad'),
              app: widget.app,
              onOpenConnection: _openConnection,
            )
          : ConnectScreen(
              key: const ValueKey<String>('connect'),
              app: widget.app,
              autoConnect: _autoConnect,
              onConnected: _onConnected,
            ),
    );
  }
}
