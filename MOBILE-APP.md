# PSP Phone Pad — Mobile App

An **additional, optional** native controller for the PSP Phone Pad project.
The existing web controller in [`README.md`](README.md) is complete, works
today, and stays the default. This document is the plan for the mobile app, not
a replacement for the web pad.

> **Status: design only.** No app code or UDP bridge exists yet. Until it does,
> use the web controller.

## Why a mobile app

The web pad already runs on Android and iPhone with no install. The app adds:

- an app icon and a true fullscreen, landscape-locked, immersive view;
- direct touch handling with no browser chrome or browser input overhead;
- haptics on button presses;
- better Wi-Fi power management on Android (high-performance `WifiLock`,
  battery-optimisation exemption);
- a USB-cable option on Android.

Everything else — the pad layout, SVG icons, drag-to-reposition editor,
per-control size sliders, and press / long-press button growth — is ported from
the web UI.

## Where PPSSPP runs

PPSSPP stays on the Linux PC. The phone is only the controller. The PC bridge
still creates the same virtual **Microsoft X-Box 360 pad** through
`/dev/uinput`, so PPSSPP and the existing `controls.ini` mapping keep working
unchanged.

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
  hotspot, or the phone's own hotspot with the PC joined to it.
- **USB on Android** is USB tethering: the PC gets an address such as
  `192.168.42.x` and the same UDP protocol runs over that interface. No extra
  app code, only a different saved IP.
- **USB on iPhone is not possible** for a normal app — iOS does not expose the
  USB link as a general data channel. iPhone is Wi-Fi only.

## Stack

One **Flutter** codebase for both platforms:

| Concern | Choice |
|---|---|
| UI | Flutter widgets, `flutter_svg` for the existing SVG icons |
| Settings | `shared_preferences` (replaces `localStorage`) |
| Display | landscape lock, immersive fullscreen, `wakelock_plus` |
| Feedback | `HapticFeedback` on press |
| Transport | `RawDatagramSocket` — built in, no plugin |
| Sampling | up to 120 Hz while active |

No cloud, no analytics, no internet dependency.

## PC-side changes

Extend `server.py` instead of replacing it:

1. Keep the WebSocket path on TCP **8080**.
2. Add an asyncio UDP endpoint on **8081**.
3. Decode the binary packet and update the existing `VirtualPad`.
4. Release all buttons and centre the sticks if no packet arrives for ~400 ms,
   so a dropped Wi-Fi link cannot leave an input stuck.
5. Print the UDP port and all local IPs on startup.
6. Add a systemd user service so the bridge starts with the session.

### Packet format (proposed)

Full state on every packet, about 19 bytes:

```
magic "PSP1" (4 bytes)
seq        u16
buttons    u16
hat        u8
LX  LY  RX  RY   i16 × 4
LT  RT           u8 × 2
```

Full snapshots self-correct after a lost packet, unlike button down/up events.
Send at ~120 Hz while a control is active, a slow heartbeat when idle, and
immediately on any button change.

## App screens

1. **Connect** — last IP pre-filled, manual IP + port, USB-tethering hint,
   connection status and round-trip time.
2. **Pad** — D-pad, analog stick, face buttons, L/R, MENU / FF / REW,
   START / SELECT.
3. **Settings** — global and per-control size sliders, dead-zone, haptics
   on/off, reset.
4. **Edit layout** — tap to select, drag to move, slider to resize; saved per
   device.
5. **Diagnostics** — packets per second, latency, last error.

## Offline behaviour

The app never needs the internet: only local sockets. It works on a LAN, a
phone hotspot, or a USB tether with no WAN connection. Android needs the
`INTERNET` permission (local sockets require it); iOS shows its **Local
Network** prompt on first connect.

Two honest caveats:

- The app does **not** remove the PC. PPSSPP still runs on the PC and still
  needs the local link. The only truly PC-free option is running PPSSPP on the
  phone itself, which is a different setup.
- Broadcast/multicast discovery on iOS requires Apple's Multicast Networking
  entitlement, so **v1 uses manual IP entry plus the last saved address**
  (Bonjour is an alternative). No broadcast dependency.

## Latency expectations

| Link | Typical added latency | Notes |
|---|---:|---|
| USB tether (Android) | < 1–2 ms | Fastest, needs a cable |
| Wi-Fi 5 GHz, UDP | 1–5 ms | Best wireless choice |
| Wi-Fi 2.4 GHz, UDP | 3–10 ms | More interference |
| Current browser WebSocket | 3–10 ms + browser overhead | Already local-only |

Touch sampling and the phone's input pipeline add roughly 10–30 ms regardless
of transport, so a clean network matters more than the link type.

## Build plan

| Phase | Work | Estimate |
|---|---|---|
| 0 | UDP bridge, binary codec, timeout release, startup banner, service | ~1 day |
| 1 | Flutter project, landscape/fullscreen, pad UI, SVG icons, press scaling | ~3–4 days |
| 2 | UDP sender, manual IP, reconnect, status/RTT, USB-tether docs | ~1–2 days |
| 3 | Layout sliders, drag editor, reset, `shared_preferences` | ~1 day |
| 4 | Android release APK, icon/splash; iOS on macOS + Xcode | ~1 day + iOS setup |

Realistic total: about **1–2 weeks** for both platforms, assuming a Mac is
available for iOS. Android alone is quicker.

## Building it (once implemented)

**Android — can be built on Linux:**

```bash
# one-time
sudo snap install flutter --classic     # or install the Flutter SDK
flutter doctor
flutter config --enable-android

# in the app project
flutter pub get
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk

adb install -r build/app/outputs/flutter-apk/app-release.apk
```

**iPhone — requires macOS + Xcode:**

```bash
flutter build ipa --release
# then sign/upload in Xcode, or install with a provisioning profile
```

- Building or installing an iOS app **cannot be done from Linux**.
- Free Apple provisioning expires after 7 days; TestFlight/App Store needs a
  paid Apple Developer account.
- Without a Mac, ship Android first and keep the iPhone on the web controller.

**Connecting the app**

1. Start the PC server as usual (`./start.sh`).
2. Wi-Fi: enter the PC's LAN IP and port 8081.
3. Android USB: enable USB tethering, then use the PC's new `192.168.42.x`
   address (`ip -4 addr`).
4. iPhone: enter the PC's Wi-Fi IP manually; accept the Local Network prompt.

## Open decisions

1. Is a Mac with Xcode available? If not, Android-first with web for iPhone.
2. Minimum versions: Android 9+ and iOS 14+.
3. Optional pairing code/token, or trust the LAN like the web pad?
4. Confirm Android-first, validate latency, then build iOS.

## Security

As with the web page, the UDP bridge will accept input from the LAN. Use it on
a trusted network. An optional pairing token can be added later; until then,
treat the bridge like the current open web controller.
