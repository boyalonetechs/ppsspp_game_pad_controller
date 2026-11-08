import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:psp_phone_pad_app/src/protocol.dart';
import 'package:psp_phone_pad_app/src/transport.dart';

void main() {
  test('connects to a local echo bridge and releases cleanly', () async {
    final RawDatagramSocket bridge = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    bridge.listen((RawSocketEvent event) {
      if (event != RawSocketEvent.read) return;
      while (true) {
        final Datagram? received = bridge.receive();
        if (received == null) break;
        final Uint8List data = received.data;
        if (data.length != kPacketSize) continue;
        final ByteData packet = ByteData.sublistView(data);
        if (packet.getUint32(0, Endian.big) != 0x50535031) continue;
        final ByteData echo = ByteData(6);
        for (int i = 0; i < kMagic.length; i++) {
          echo.setUint8(i, kMagic[i]);
        }
        echo.setUint16(4, packet.getUint16(4, Endian.little), Endian.little);
        bridge.send(echo.buffer.asUint8List(), received.address, received.port);
      }
    });

    final PadLink link = PadLink();
    addTearDown(() {
      link.dispose();
      bridge.close();
    });

    final bool connected = await link.connect('127.0.0.1', bridge.port);
    expect(connected, isTrue);
    expect(link.status, LinkStatus.connected);
    expect(link.isOpen, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(link.rttMs, greaterThanOrEqualTo(0));
    expect(link.pps, greaterThan(0));

    link.button(PadButton.cross, true);
    expect(link.state.isDown(PadButton.cross), isTrue);
    expect(link.state.buttons, isNot(0));

    link.releaseAll();
    expect(link.state.buttons, 0);
    expect(link.state.hat, 5);

    await link.close();
    expect(link.status, LinkStatus.idle);
    expect(link.isOpen, isFalse);
  });
}
