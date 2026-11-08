import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'src/app_state.dart';
import 'src/layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  AppSettings settings;
  PadLayout layout;
  try {
    settings = await AppSettings.load();
    layout = await LayoutStore.load();
  } catch (_) {
    settings = AppSettings();
    layout = PadLayout.defaults();
  }
  final AppState app = AppState(settings: settings, layout: layout);
  runApp(PadApp(app: app));
}
