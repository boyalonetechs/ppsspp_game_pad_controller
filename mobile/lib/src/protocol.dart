import 'dart:typed_data';

const List<int> kMagic = <int>[0x50, 0x53, 0x50, 0x31];
const int kPacketSize = 19;
const int kDefaultPort = 8081;

enum PadButton {
  triangle,
  circle,
  cross,
  square,
  l,
  r,
  select,
  start,
  guide,
  l3,
  r3,
}

class PadState {
  int buttons = 0;
  int hat = 5;
  double leftX = 0;
  double leftY = 0;
  double rightX = 0;
  double rightY = 0;
  int leftTrigger = 0;
  int rightTrigger = 0;

  bool isDown(PadButton button) => buttons & (1 << button.index) != 0;

  void setButton(PadButton button, bool down) {
    final int mask = 1 << button.index;
    buttons = down ? buttons | mask : buttons & ~mask;
  }

  void setHat(int x, int y) {
    hat = ((x + 1) & 0x03) | (((y + 1) & 0x03) << 2);
  }

  bool get isActive =>
      buttons != 0 ||
      hat != 5 ||
      leftX != 0 ||
      leftY != 0 ||
      rightX != 0 ||
      rightY != 0 ||
      leftTrigger != 0 ||
      rightTrigger != 0;

  void reset() {
    buttons = 0;
    hat = 5;
    leftX = 0;
    leftY = 0;
    rightX = 0;
    rightY = 0;
    leftTrigger = 0;
    rightTrigger = 0;
  }
}

Uint8List encodePadPacket(int sequence, PadState state) {
  final ByteData data = ByteData(kPacketSize);
  for (int i = 0; i < kMagic.length; i++) {
    data.setUint8(i, kMagic[i]);
  }
  data.setUint16(4, sequence & 0xffff, Endian.little);
  data.setUint16(6, state.buttons & 0xffff, Endian.little);
  data.setUint8(8, state.hat & 0xff);
  data.setInt16(9, _axisValue(state.leftX), Endian.little);
  data.setInt16(11, _axisValue(state.leftY), Endian.little);
  data.setInt16(13, _axisValue(state.rightX), Endian.little);
  data.setInt16(15, _axisValue(state.rightY), Endian.little);
  data.setUint8(17, state.leftTrigger.clamp(0, 255));
  data.setUint8(18, state.rightTrigger.clamp(0, 255));
  return data.buffer.asUint8List();
}

int? decodeEcho(Uint8List data) {
  if (data.length != 6) return null;
  for (int i = 0; i < kMagic.length; i++) {
    if (data[i] != kMagic[i]) return null;
  }
  return ByteData.sublistView(data).getUint16(4, Endian.little);
}

int _axisValue(double value) {
  final double clamped = value.clamp(-1.0, 1.0);
  return (clamped * 32767).round();
}
