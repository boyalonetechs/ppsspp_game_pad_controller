import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:psp_phone_pad_app/src/layout.dart';
import 'package:psp_phone_pad_app/src/protocol.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('encodes a full pad snapshot', () {
    final PadState state = PadState()
      ..setButton(PadButton.cross, true)
      ..setButton(PadButton.start, true)
      ..setHat(-1, 1)
      ..leftX = 0.5
      ..leftY = -0.25
      ..rightX = 1
      ..rightY = -1
      ..leftTrigger = 123
      ..rightTrigger = 45;

    final Uint8List packet = encodePadPacket(513, state);
    final ByteData data = ByteData.sublistView(packet);

    expect(packet.length, kPacketSize);
    expect(packet.sublist(0, 4), kMagic);
    expect(data.getUint16(4, Endian.little), 513);
    expect(
      data.getUint16(6, Endian.little),
      (1 << PadButton.cross.index) | (1 << PadButton.start.index),
    );
    expect(data.getUint8(8), 0 | (2 << 2));
    expect(data.getInt16(9, Endian.little), 16384);
    expect(data.getInt16(11, Endian.little), -8192);
    expect(data.getInt16(13, Endian.little), 32767);
    expect(data.getInt16(15, Endian.little), -32767);
    expect(data.getUint8(17), 123);
    expect(data.getUint8(18), 45);
  });

  test('decodes the echo sequence', () {
    final Uint8List echo = Uint8List.fromList(<int>[
      0x50,
      0x53,
      0x50,
      0x31,
      0x2A,
      0x01,
    ]);
    expect(decodeEcho(echo), 298);
    expect(decodeEcho(Uint8List.fromList(<int>[1, 2, 3])), isNull);
    expect(decodeEcho(Uint8List.fromList(<int>[0, 0, 0, 0, 1, 0])), isNull);
  });

  test('layout round-trips through json', () {
    final PadLayout layout = PadLayout.defaults()
      ..all = 1.4
      ..groups[PadGroup.dpad]!.dx = 24
      ..groups[PadGroup.dpad]!.spread = -12
      ..groups[PadGroup.face]!.scale = 1.7;

    final PadLayout restored = PadLayout.fromJson(layout.toJson());

    expect(restored.all, 1.4);
    expect(restored.groups[PadGroup.dpad]!.dx, 24);
    expect(restored.groups[PadGroup.dpad]!.spread, -12);
    expect(restored.groups[PadGroup.face]!.scale, 1.7);
  });

  test('layout clamps corrupt values', () {
    final PadLayout layout = PadLayout.fromJson(<String, dynamic>{
      'all': 9,
      'groups': <String, dynamic>{
        'l': <String, dynamic>{'s': 99, 'dx': -99999, 'spread': 500},
      },
    });
    expect(layout.all, 2);
    expect(layout.groups[PadGroup.l]!.scale, 2.5);
    expect(layout.groups[PadGroup.l]!.dx, -4000);
    expect(layout.groups[PadGroup.l]!.spread, 28);
  });

  test('background settings round-trip', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppSettings settings = AppSettings(
      backgroundColor: 0xFF112233,
      backgroundImage: '/tmp/pad-background.jpg',
      backgroundDim: 0.42,
    );

    await settings.save();
    final AppSettings restored = await AppSettings.load();

    expect(restored.backgroundColor, 0xFF112233);
    expect(restored.backgroundImage, '/tmp/pad-background.jpg');
    expect(restored.backgroundDim, 0.42);
  });
}
