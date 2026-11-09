import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'layout.dart';
import 'transport.dart';

class AppState extends ChangeNotifier {
  AppState({required this.settings, required this.layout});

  final AppSettings settings;
  PadLayout layout;
  final PadLink link = PadLink();

  int releaseToken = 0;
  bool editing = false;
  PadGroup selectedGroup = PadGroup.dpad;

  Timer? _layoutSave;
  Timer? _settingsSave;

  Future<bool> connect(String host, int port) async {
    settings.host = host.trim();
    settings.port = port;
    final bool ok = await link.connect(settings.host, settings.port);
    if (ok) _scheduleSettingsSave();
    notifyListeners();
    return ok;
  }

  Future<void> disconnect() async {
    await link.close();
    notifyListeners();
  }

  void releaseAll() {
    link.releaseAll();
    releaseToken++;
    notifyListeners();
  }

  void setEditing(bool value) {
    editing = value;
    notifyListeners();
  }

  void selectGroup(PadGroup group) {
    selectedGroup = group;
    notifyListeners();
  }

  void updateGroup(
    PadGroup group, {
    double? dx,
    double? dy,
    double? scale,
    double? spread,
    bool persist = false,
  }) {
    final GroupLayout value = layout.groups[group]!;
    if (dx != null) value.dx = dx.clamp(-4000.0, 4000.0);
    if (dy != null) value.dy = dy.clamp(-4000.0, 4000.0);
    if (scale != null) value.scale = scale.clamp(0.3, group.maxScale);
    if (spread != null) value.spread = spread.clamp(-30.0, 28.0);
    notifyListeners();
    if (persist) persistLayout();
  }

  void setAll(double value) {
    layout.all = value.clamp(0.5, 2.0);
    notifyListeners();
    _scheduleLayoutSave();
  }

  void setGroupScale(PadGroup group, double value) {
    layout.groups[group]!.scale = value.clamp(0.3, group.maxScale);
    notifyListeners();
    _scheduleLayoutSave();
  }

  void setSpread(PadGroup group, double value) {
    layout.groups[group]!.spread = value.clamp(-30.0, 28.0);
    notifyListeners();
    _scheduleLayoutSave();
  }

  void setDeadzone(double value) {
    settings.deadzone = value.clamp(0.0, 0.35);
    notifyListeners();
    _scheduleSettingsSave();
  }

  void setHaptics(bool value) {
    settings.haptics = value;
    notifyListeners();
    _scheduleSettingsSave();
  }

  void setBackgroundColor(int value) {
    settings.backgroundColor = value;
    notifyListeners();
    _scheduleSettingsSave();
  }

  void setBackgroundDim(double value) {
    settings.backgroundDim = value.clamp(0.0, 0.9);
    notifyListeners();
    _scheduleSettingsSave();
  }

  Future<bool> setBackgroundImage(String sourcePath) async {
    try {
      final Directory support = await getApplicationSupportDirectory();
      final Directory folder = Directory('${support.path}/backgrounds');
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      final String extension = _imageExtension(sourcePath);
      final String stamp = DateTime.now().microsecondsSinceEpoch.toString();
      final File target = File(
        '${folder.path}/pad-background-$stamp.$extension',
      );
      await File(sourcePath).copy(target.path);
      settings.backgroundImage = target.path;
      notifyListeners();
      _scheduleSettingsSave();
      try {
        await for (final FileSystemEntity entity in folder.list()) {
          if (entity is File && entity.path != target.path) {
            await entity.delete();
          }
        }
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearBackgroundImage() async {
    final String path = settings.backgroundImage;
    settings.backgroundImage = '';
    if (path.isNotEmpty) {
      try {
        final File file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    notifyListeners();
    _scheduleSettingsSave();
  }

  void resetLayout() {
    layout = PadLayout.defaults();
    notifyListeners();
    persistLayout();
  }

  void persistLayout() {
    _layoutSave?.cancel();
    _layoutSave = null;
    LayoutStore.save(layout);
  }

  void _scheduleLayoutSave() {
    _layoutSave?.cancel();
    _layoutSave = Timer(const Duration(milliseconds: 300), () {
      LayoutStore.save(layout);
    });
  }

  void _scheduleSettingsSave() {
    _settingsSave?.cancel();
    _settingsSave = Timer(const Duration(milliseconds: 300), () {
      settings.save();
    });
  }

  @override
  void dispose() {
    _layoutSave?.cancel();
    _settingsSave?.cancel();
    link.dispose();
    super.dispose();
  }
}

String _imageExtension(String path) {
  final String name = path.split(RegExp(r'[/\\]')).last;
  final int dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return 'jpg';
  final String extension = name.substring(dot + 1).toLowerCase();
  if (extension.length > 5 || !RegExp(r'^[a-z0-9]+$').hasMatch(extension)) {
    return 'jpg';
  }
  return extension;
}
