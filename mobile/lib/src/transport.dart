import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'protocol.dart';

enum LinkStatus { idle, connecting, connected, offline }

class PadLink extends ChangeNotifier {
  final PadState state = PadState();

  RawDatagramSocket? _socket;
  InternetAddress? _target;
  int _port = kDefaultPort;
  Timer? _ticker;
  Timer? _statsTimer;
  Completer<bool>? _firstEcho;
  DateTime? _lastEcho;
  final Map<int, DateTime> _pending = <int, DateTime>{};

  LinkStatus _status = LinkStatus.idle;
  int _rttMs = 0;
  int _pps = 0;
  int _sentCount = 0;
  int _lostCount = 0;
  int _sequence = 0;
  DateTime _lastSend = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
  String _error = '';

  LinkStatus get status => _status;
  int get rttMs => _rttMs;
  int get pps => _pps;
  int get lostCount => _lostCount;
  String get error => _error;
  bool get isOpen => _socket != null;
  bool get connected => _status == LinkStatus.connected;

  Future<bool> connect(String host, int port) async {
    await close();
    state.reset();
    _error = '';
    final String trimmed = host.trim();
    if (trimmed.isEmpty) {
      _fail('Enter the laptop address');
      return false;
    }
    final InternetAddress? address = await _resolve(trimmed);
    if (address == null) {
      _fail('Unknown address "$trimmed"');
      return false;
    }
    try {
      final RawDatagramSocket socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      socket.broadcastEnabled = true;
      _socket = socket;
      _target = address;
      _port = port;
      socket.listen(_handleEvent);
    } catch (error) {
      _fail('Could not open network: $error');
      return false;
    }
    _firstEcho = Completer<bool>();
    _setStatus(LinkStatus.connecting);
    _lastEcho = null;
    _rttMs = 0;
    _ticker?.cancel();
    _statsTimer?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 8), (_) => _tick());
    _statsTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickStats(),
    );
    _send(force: true);
    final bool ok = await _firstEcho!.future.timeout(
      const Duration(milliseconds: 1600),
      onTimeout: () => false,
    );
    if (!ok && _status == LinkStatus.connecting) {
      _error = 'No response from the laptop';
      _setStatus(LinkStatus.offline);
    }
    return ok;
  }

  Future<InternetAddress?> _resolve(String host) async {
    final InternetAddress? parsed = InternetAddress.tryParse(host);
    if (parsed != null) return parsed;
    try {
      final List<InternetAddress> results = await InternetAddress.lookup(host);
      for (final InternetAddress address in results) {
        if (address.type == InternetAddressType.IPv4) return address;
      }
      if (results.isNotEmpty) return results.first;
    } catch (_) {}
    return null;
  }

  void button(PadButton button, bool down) {
    state.setButton(button, down);
    pulse();
  }

  void axis(double x, double y) {
    state.leftX = x;
    state.leftY = y;
    pulse();
  }

  void hat(int x, int y) {
    state.setHat(x, y);
    pulse();
  }

  void triggers(int left, int right) {
    state.leftTrigger = left;
    state.rightTrigger = right;
    pulse();
  }

  void pulse() {
    _send();
  }

  void releaseAll() {
    state.reset();
    _send(force: true);
    notifyListeners();
  }

  void _handleEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final RawDatagramSocket? socket = _socket;
    if (socket == null) return;
    Datagram? datagram;
    while ((datagram = socket.receive()) != null) {
      final int? sequence = decodeEcho(datagram!.data);
      if (sequence == null) continue;
      final DateTime now = DateTime.now();
      final DateTime? sentAt = _pending.remove(sequence);
      if (sentAt != null) {
        final int sample = now.difference(sentAt).inMilliseconds.clamp(0, 999);
        _rttMs = _rttMs == 0 ? sample : ((_rttMs * 3 + sample) / 4).round();
      }
      _lastEcho = now;
      _error = '';
      final Completer<bool>? completer = _firstEcho;
      if (completer != null && !completer.isCompleted) completer.complete(true);
      if (_status != LinkStatus.connected) _setStatus(LinkStatus.connected);
      _notifyThrottled();
    }
  }

  void _notifyThrottled() {
    final DateTime now = DateTime.now();
    if (now.difference(_lastNotify) < const Duration(milliseconds: 250)) return;
    _lastNotify = now;
    notifyListeners();
  }

  void _tick() {
    final DateTime now = DateTime.now();
    if (!state.isActive &&
        now.difference(_lastSend) < const Duration(milliseconds: 250)) {
      return;
    }
    _send();
  }

  void _send({bool force = false}) {
    final RawDatagramSocket? socket = _socket;
    final InternetAddress? target = _target;
    if (socket == null || target == null) return;
    final DateTime now = DateTime.now();
    if (!force && now.difference(_lastSend) < const Duration(milliseconds: 4)) {
      return;
    }
    _lastSend = now;
    _sequence = (_sequence + 1) & 0xffff;
    _pending[_sequence] = now;
    if (_pending.length > 64) {
      _pending.remove(_pending.keys.first);
      _lostCount++;
    }
    try {
      socket.send(encodePadPacket(_sequence, state), target, _port);
      _sentCount++;
    } catch (_) {}
  }

  void _tickStats() {
    _pps = _sentCount;
    _sentCount = 0;
    final DateTime now = DateTime.now();
    _pending.removeWhere((int sequence, DateTime sentAt) {
      if (now.difference(sentAt) > const Duration(seconds: 2)) {
        _lostCount++;
        return true;
      }
      return false;
    });
    if (_status == LinkStatus.connected) {
      final DateTime? last = _lastEcho;
      if (last != null &&
          now.difference(last) > const Duration(milliseconds: 1500)) {
        _setStatus(LinkStatus.offline);
      }
    }
    notifyListeners();
  }

  void _fail(String message) {
    _error = message;
    _setStatus(LinkStatus.offline);
    final Completer<bool>? completer = _firstEcho;
    if (completer != null && !completer.isCompleted) completer.complete(false);
  }

  void _setStatus(LinkStatus status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }

  Future<void> close() async {
    _ticker?.cancel();
    _statsTimer?.cancel();
    _ticker = null;
    _statsTimer = null;
    _socket?.close();
    _socket = null;
    _target = null;
    _pending.clear();
    _firstEcho = null;
    _status = LinkStatus.idle;
    _rttMs = 0;
    _pps = 0;
    _lastEcho = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _statsTimer?.cancel();
    _socket?.close();
    super.dispose();
  }
}
