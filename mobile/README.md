# PSP Phone Pad — mobile app

Flutter controller for the PSP Phone Pad project. The app is a pad only: PPSSPP
runs on the laptop and receives input through `server.py` and `/dev/uinput`.

The web controller in the repository root remains the default. This app adds a
native fullscreen pad, haptics, saved layouts and a UDP link on port `8081`.

## Requirements

- Flutter 3.38 or newer
- Android 9+ or iOS 14+
- The laptop server running on the same network

## Run

```bash
flutter pub get
flutter run
```

On first launch, enter the laptop address printed by `./start.sh` on the laptop
(`http://192.168.x.x:8080` means the app address is the same IP with UDP port
`8081`). The last working address is saved.

Controls:

- Connect screen: address, port, status.
- Pad: D-pad, analog stick, face buttons, L/R, MENU, FF, REW, SELECT, START.
  The connection status sits at the top; the action row sits at the bottom.
- Settings: all sizes, per-control sizes, D-pad/face spacing, dead zone,
  haptics, a custom background color or photo with image shade, reset and live
  link diagnostics.
- Edit layout: drag to move, pinch the D-pad or face buttons to cluster or
  spread them, use the slider to resize, nudge buttons for fine placement,
  reset to defaults. The toolbar floats centered and collapses out of the way.
  The layout and background are stored per device.

## Build

Android:

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The release APK is signed with the local debug key, which is fine for
sideloading. Use your own keystore before publishing.

iOS needs macOS and Xcode:

```bash
flutter build ipa --release
```

The app is landscape locked and immersive. Android USB works through USB
tethering (`192.168.42.x`). iPhone is Wi-Fi only.

## Tests

```bash
flutter test
flutter analyze
```

`test/protocol_test.dart` checks the binary packet and saved layout format.
`test/transport_test.dart` runs the link against a local UDP echo bridge.
`test/screens_test.dart` renders the pad, edit mode, settings and connect
screens at phone landscape sizes.

## Structure

```
lib/main.dart                     app bootstrap and display mode
lib/app.dart                      theme and connect/pad switching
lib/src/protocol.dart             PSP1 packet encode/decode
lib/src/transport.dart            RawDatagramSocket link, RTT and rate
lib/src/app_state.dart            connection, layout and settings state
lib/src/layout.dart               saved layout and preferences
lib/src/theme.dart                etched style and custom painters
lib/src/screens/                  connect, pad and controls dialog
lib/src/widgets/                  pad controls, backdrop and press handling
tool/generate_icons.swift         app icon and launch image generator
```
