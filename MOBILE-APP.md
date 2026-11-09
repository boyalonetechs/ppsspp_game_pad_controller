# PSP Phone Pad — Mobile App

An **additional, optional** native controller for the PSP Phone Pad project.
The web controller in [`README.md`](README.md) is complete, works today, and
stays the default. This document covers the native app and the UDP bridge that
backs it.

> **Status: implemented on the `dev` branch.** The UDP bridge is part of
> `server.py`, and the Flutter app is in [`mobile/`](mobile/). The web pad is
> unchanged and still the zero-install option.

> **PPSSPP keeps running on the laptop.** The mobile app is only a
> **pad/controller** for that laptop — it does not emulate games and does not
> run PPSSPP on the phone.

## Why a mobile app

The web pad already runs on Android and iPhone with no install. The app adds:

- an app icon and a true fullscreen, landscape-locked, immersive view;
- direct touch handling with no browser chrome or browser input overhead;
- haptics on button presses and hold feedback;
- a saved, per-device layout with global and per-control sizes and spacing;
- pinch-to-cluster and pinch-to-spread face buttons and D-pad;
- a centered, collapsible layout editor;
- a custom background color or photo with an outlined “Boy Alone” mark;
- a dead-zone control and live link diagnostics;
- a USB-cable option on Android.

Everything else — the pad layout, etched SVG icons, drag-to-reposition editor,
per-control size sliders, and press / long-press button growth — is ported from
the web UI.

## Where PPSSPP runs

PPSSPP runs on the **laptop**, exactly as it does with the web controller. The
phone app is only the pad: it sends button and stick state to the laptop's
`server.py`, which drives the same virtual **Microsoft X-Box 360 pad** through
`/dev/uinput`. The existing PPSSPP `controls.ini` mapping keeps working
unchanged.

Running PPSSPP (or any emulator) on the phone is **not** part of this project.

```
 Flutter app (Android / iPhone)
   ├── Wi-Fi UDP ───────────────┐
   └── USB tether (Android) ────┤
                                ▼
                server.py — UDP receiver on :8081
                existing WebSocket server on :8080
                                ▼
                VirtualPad → /dev/uinput
                                ▼
                Microsoft X-Box 360 pad → PPSSPP
```

The web controller keeps using WebSocket on TCP **8080**. The app uses UDP on
**8081**. Both can be served at the same time; they share one virtual pad, so
use one controller at a time.

## Transports

| | Wi-Fi UDP | USB |
|---|---|---|
| **Android** | ✅ | ✅ via USB tethering |
| **iPhone** | ✅ | ❌ not available to normal apps |

- **Wi-Fi UDP** is the default on both platforms and works over a router, a
  hotspot, or the phone's own hotspot with the laptop joined to it.
- **USB on Android** is USB tethering: the laptop gets an address such as
  `192.168.42.x` and the same UDP protocol runs over that interface. No extra
  app code, only a different saved IP.
- **USB on iPhone is not possible** for a normal app — iOS does not expose the
  USB link as a general data channel. iPhone is Wi-Fi only.

## Stack

One **Flutter** codebase for both platforms:

| Concern | Choice |
|---|---|
| UI | Flutter widgets and custom painters, `flutter_svg` for icons |
| Settings | `shared_preferences` |
| Background photo | `image_picker`, `path_provider` |
| Display | landscape lock, immersive fullscreen, `wakelock_plus` |
| Feedback | `HapticFeedback` on press and hold |
| Transport | `RawDatagramSocket` — built in, no plugin |
| Sampling | up to 125 Hz while active, 250 ms heartbeat when idle |

No cloud, no analytics, no internet dependency.

## Laptop-side implementation

`server.py` keeps the WebSocket path on TCP **8080** and adds:

1. An asyncio UDP endpoint on **8081**, enabled by default.
2. A 19-byte binary decoder that updates the existing `VirtualPad`, including
   left/right axes and analog triggers.
3. A full snapshot applied on every packet, so a lost packet self-corrects.
4. A 400 ms watchdog that releases all buttons and centres the sticks if the
   phone disappears.
5. An echo reply (`PSP1` + sequence) for round-trip measurement and connection
   detection.
6. Startup output with the UDP port and every local IP, plus UDP fields in
   `/health`:
   `udp_port`, `udp_active`, `udp_packets`.
7. A systemd user unit installed with `./install-service.sh`.

CLI switches:

```bash
./start.sh --no-udp
./start.sh --udp-port 9001
```

## Packet format

Full state on every packet, little-endian, 19 bytes:

| Offset | Size | Field |
|---:|---:|---|
| 0 | 4 | magic `"PSP1"` |
| 4 | 2 | sequence `u16` |
| 6 | 2 | buttons `u16` |
| 8 | 1 | hat `u8` |
| 9 | 2 | left X `i16` |
| 11 | 2 | left Y `i16` |
| 13 | 2 | right X `i16` |
| 15 | 2 | right Y `i16` |
| 17 | 1 | left trigger `u8` |
| 18 | 1 | right trigger `u8` |

Button bits:

| Bit | Button | Bit | Button |
|---:|---|---:|---|
| 0 | triangle | 6 | select |
| 1 | circle | 7 | start |
| 2 | cross | 8 | guide / MENU |
| 3 | square | 9 | L3 / FF |
| 4 | L | 10 | R3 / REW |
| 5 | R | | |

- **Hat:** `(x + 1) | ((y + 1) << 2)`, where `x` and `y` are `-1`, `0` or `1`.
  Neutral is `5`.
- **Axes:** `-32767` to `32767`, with a user-adjustable dead zone in the app.
- **Triggers:** `0` to `255`. The PSP has digital L/R shoulders, so the app
  sends `0`; the fields are reserved.
- **Right stick:** reserved. The PSP has one analog nub, so the app sends zero.
- **Echo:** the server replies with `"PSP1"` plus the packet sequence (6 bytes).
  The app uses it for RTT, packet-rate and connection state. Packets with the
  wrong length or magic are ignored.

The app sends at up to 125 Hz while a control is active, sends immediately on a
change, and falls back to a 250 ms heartbeat when idle. The server releases the
pad after 400 ms without a packet.

## App screens

1. **Connect** — last IP pre-filled, automatic reconnect on launch, manual IP
   and port, Wi-Fi / USB-tethering hints, status and round-trip time.
2. **Pad** — D-pad, analog stick, face buttons, L/R, MENU / FF / REW,
   START / SELECT, with press and hold growth and optional haptics.
3. **Controls** — global and per-control size sliders, D-pad and face spacing,
   a background color or photo with image shade, dead zone, haptics, reset, and
   live link diagnostics (status, RTT, send rate, address).
4. **Edit layout** — tap a control to select, drag to move, pinch the D-pad or
   face buttons to cluster or spread them, use the slider to resize, nudge for
   fine placement, and collapse the centered toolbar to reach covered controls.
   Saved per device.
5. **Link handling** — continues heartbeating after a drop, marks the link
   offline after 1.5 s without an echo, and releases every input when the app
   goes to the background.

There is no separate diagnostics screen; link statistics live in the Controls
dialog.

## Offline behaviour

The app never needs the internet: only local sockets. It works on a LAN, a
phone hotspot, or a USB tether with no WAN connection. Android needs the
`INTERNET` permission (local sockets require it); iOS shows its **Local
Network** prompt on first connect.

A few honest caveats:

- The app does **not** remove the laptop. PPSSPP still runs there and still
  needs the local link; the phone is only the controller.
- Running PPSSPP on the phone is explicitly out of scope.
- Broadcast/multicast discovery on iOS requires Apple's Multicast Networking
  entitlement, so this version uses manual IP entry plus the last saved address.
  No broadcast dependency.

## Latency expectations

- The link itself is small: 19 bytes per state packet at 125 Hz is about
  2.4 KB/s, plus 6-byte echoes.
- Wi-Fi adds a few milliseconds and some jitter; 5 GHz or 6 GHz is cleaner than
  2.4 GHz. USB tethering removes Wi-Fi from the path but keeps the same touch
  pipeline.
- Touch sampling and the phone's input/display pipeline add roughly 10–30 ms
  regardless of transport, so network quality matters more than the link type.
- The round-trip time shown in the app is UDP echo RTT, not input-to-photon
  latency.

## Build and run

**Laptop:**

```bash
./start.sh
```

Read the **Mobile app** address and port `8081` from the banner.

**Android:**

```bash
cd mobile
flutter pub get
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

**iPhone — requires macOS + Xcode:**

```bash
cd mobile
flutter run
flutter build ipa --release
```

- Building or installing an iOS app cannot be done from Linux.
- Free Apple provisioning expires after 7 days; TestFlight/App Store needs a
  paid Apple Developer account.
- The release APK uses the local debug signing key, which is fine for
  sideloading. Add a release keystore before publishing to Google Play.
- Without a Mac, ship Android first and keep the iPhone on the web controller.

**Connecting the app:**

1. Start the laptop server as usual (`./start.sh`).
2. Wi-Fi: enter the laptop's LAN IP and port `8081`.
3. Android USB: enable USB tethering, then use the laptop's new `192.168.42.x`
   address (`ip -4 addr`).
4. iPhone: enter the laptop's Wi-Fi IP; accept the Local Network prompt.

The address is saved and retried automatically on the next launch.

## Tests

```bash
cd mobile
flutter test
flutter analyze
```

The app suite covers packet encoding/decoding, layout clamping and JSON
round-trip, a live UDP echo connection, and renders the pad, edit mode, settings
dialog, connect screen and a smaller phone layout.

The laptop bridge has its own tests:

```bash
python3 -m unittest discover -s tests -v
```

## Project layout

```
server.py                         TCP web pad + UDP bridge + virtual pad
install-service.sh                systemd user unit installer
systemd/psp-phone-pad.service.in  unit template
tests/test_udp_bridge.py          packet, pad and watchdog tests
mobile/
  lib/main.dart                   bootstrap, landscape and immersive mode
  lib/app.dart                    theme and connect/pad switching
  lib/src/protocol.dart           PSP1 packet encode/decode
  lib/src/transport.dart          UDP socket, RTT, rate, reconnect state
  lib/src/app_state.dart          connection, layout and settings state
  lib/src/layout.dart             saved layout and preferences
  lib/src/theme.dart              etched style and custom painters
  lib/src/screens/                connect, pad, controls dialog
  lib/src/widgets/                pad controls, backdrop and press handling
  test/                           protocol, layout, transport, screens
  tool/generate_icons.swift       app icon and launch image generator
```

## Decisions

1. A Mac with Xcode is available, so both platforms are built from one Flutter
   project.
2. Minimum versions: Android 9+ and iOS 14+.
3. No pairing token in v1; the bridge trusts the LAN like the web pad.
4. The right stick and analog triggers are reserved on the wire but not exposed
   in the UI, matching the PSP's single nub and digital shoulders.

## Security

As with the web page, the UDP bridge accepts input from the LAN. Use it on a
trusted network. A pairing token can be added later; until then, treat the
bridge like the current open web controller and stop it when not in use.
