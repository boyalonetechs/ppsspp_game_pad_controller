import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'protocol.dart';

enum PadGroup { dpad, stick, face, l, r, center }

extension PadGroupInfo on PadGroup {
  String get label => switch (this) {
    PadGroup.dpad => 'D-pad',
    PadGroup.stick => 'Analog',
    PadGroup.face => 'Face buttons',
    PadGroup.l => 'L shoulder',
    PadGroup.r => 'R shoulder',
    PadGroup.center => 'Start / hotkeys',
  };

  String get shortLabel => switch (this) {
    PadGroup.dpad => 'D-PAD',
    PadGroup.stick => 'STICK',
    PadGroup.face => 'FACE',
    PadGroup.l => 'L',
    PadGroup.r => 'R',
    PadGroup.center => 'CENTER',
  };

  bool get usesSpread => this == PadGroup.dpad || this == PadGroup.face;

  double get maxScale => this == PadGroup.l || this == PadGroup.r ? 2.5 : 2.2;
}

class GroupLayout {
  GroupLayout({this.dx = 0, this.dy = 0, this.scale = 1, this.spread = 0});

  double dx;
  double dy;
  double scale;
  double spread;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'dx': dx,
    'dy': dy,
    's': scale,
    'spread': spread,
  };

  factory GroupLayout.fromJson(
    Map<String, dynamic>? json, {
    required PadGroup group,
  }) {
    final GroupLayout out = GroupLayout();
    if (json == null) return out;
    out.dx = _clampDouble(json['dx'], 0, -4000, 4000);
    out.dy = _clampDouble(json['dy'], 0, -4000, 4000);
    out.scale = _clampDouble(json['s'], 1, 0.3, group.maxScale);
    out.spread = _clampDouble(json['spread'], 0, -30, 28);
    return out;
  }
}

class PadLayout {
  PadLayout({this.all = 1, Map<PadGroup, GroupLayout>? groups})
    : groups =
          groups ??
          <PadGroup, GroupLayout>{
            for (final PadGroup group in PadGroup.values) group: GroupLayout(),
          };

  double all;
  final Map<PadGroup, GroupLayout> groups;

  factory PadLayout.defaults() => PadLayout();

  Map<String, dynamic> toJson() => <String, dynamic>{
    'all': all,
    'groups': <String, dynamic>{
      for (final MapEntry<PadGroup, GroupLayout> entry in groups.entries)
        entry.key.name: entry.value.toJson(),
    },
  };

  factory PadLayout.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PadLayout.defaults();
    final Map<String, dynamic> rawGroups =
        (json['groups'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    return PadLayout(
      all: _clampDouble(json['all'], 1, 0.5, 2),
      groups: <PadGroup, GroupLayout>{
        for (final PadGroup group in PadGroup.values)
          group: GroupLayout.fromJson(
            (rawGroups[group.name] as Map?)?.cast<String, dynamic>(),
            group: group,
          ),
      },
    );
  }

  double effectiveScale(PadGroup group) =>
      (groups[group]!.scale * all).clamp(0.25, 3.0);

  factory PadLayout.decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return PadLayout.defaults();
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) return PadLayout.fromJson(decoded);
      if (decoded is Map) {
        return PadLayout.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return PadLayout.defaults();
  }
}

class LayoutStore {
  static const String key = 'pspPadLayout.v2';

  static Future<PadLayout> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return PadLayout.decode(prefs.getString(key));
  }

  static Future<void> save(PadLayout layout) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(layout.toJson()));
  }
}

class AppSettings {
  AppSettings({
    this.host = '',
    this.port = kDefaultPort,
    this.deadzone = 0.13,
    this.haptics = true,
  });

  String host;
  int port;
  double deadzone;
  bool haptics;

  static const String _hostKey = 'pspPad.host';
  static const String _portKey = 'pspPad.port';
  static const String _deadzoneKey = 'pspPad.deadzone';
  static const String _hapticsKey = 'pspPad.haptics';

  static Future<AppSettings> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int port = prefs.getInt(_portKey) ?? kDefaultPort;
    final double deadzone = prefs.getDouble(_deadzoneKey) ?? 0.13;
    return AppSettings(
      host: prefs.getString(_hostKey) ?? '',
      port: port >= 1 && port <= 65535 ? port : kDefaultPort,
      deadzone: deadzone.clamp(0.0, 0.35),
      haptics: prefs.getBool(_hapticsKey) ?? true,
    );
  }

  Future<void> save() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, host);
    await prefs.setInt(_portKey, port);
    await prefs.setDouble(_deadzoneKey, deadzone);
    await prefs.setBool(_hapticsKey, haptics);
  }
}

double _clampDouble(Object? value, double fallback, double low, double high) {
  if (value is num && value.isFinite) {
    return value.toDouble().clamp(low, high);
  }
  return fallback;
}
