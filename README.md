# PSP Phone Pad

Use your phone as a wireless PSP controller for PPSSPP on Linux machines.

The phone opens a web page — no app to install — and the PC turns its touches
into a real virtual **Xbox 360 gamepad** (`/dev/uinput`). PPSSPP sees a normal
controller with a working analog stick, so every game works, not just
keyboard-mapped ones.

An optional native Flutter app for Android and iPhone is included as well. It
uses UDP on port **8081**, has the same pad, haptics and a saved layout editor,
and works alongside the web page.

```
phone browser ──TCP 8080──┐
                          ├──►  server.py  ──uinput──►  virtual Xbox 360 pad  ──►  PPSSPP
phone app     ──UDP 8081──┘
```

## What you need

- Linux with `/dev/uinput` (machine: Ubuntu 26.04 ✓)
- Python 3 with the `websockets` package (already installed: 17.2 ✓)
- PPSSPP — you already have the **`ppsspp-emu` snap** installed ✓
- Phone and PC on the **same Wi-Fi network** (or the phone's hotspot)
- One-time `sudo` for the uinput permission setup
- Optional: Flutter 3.38+ to build the native Android/iOS app

## 1. One-time setup (needs sudo)

```bash
cd ~/psp-phone-pad
sudo ./setup-uinput.sh
```

This loads the `uinput` module, adds a udev rule so your user can create the
virtual gamepad, and confirms the PPSSPP snap's `joystick` interface is
connected. It does **not** install anything else.

## 2. Start the pad

```bash
cd ~/psp-phone-pad
./start.sh
```

The terminal prints something like:

```
Web pad:   http://192.168.43.120:8080
Mobile app: 192.168.43.120  port 8081 (UDP)
```

Start PPSSPP **after** this server (the server fixes two PPSSPP button
mappings on startup; if PPSSPP was already running, quit and reopen it).

Shortcut — start the server and launch PPSSPP together:

```bash
./start.sh --launch
```

The UDP bridge starts automatically. Disable it with `--no-udp`, or use a
different port with `--udp-port 9001`.

## Run the server in the background

Install a systemd user service instead of keeping a terminal open:

```bash
./install-service.sh
journalctl --user -u psp-phone-pad -f
```

The installer pins the service to this checkout and starts it now and at login.
Stop it with:

```bash
systemctl --user disable --now psp-phone-pad.service
```

## 3. On the phone

1. Connect the phone to the same Wi-Fi / hotspot as the PC.
2. Open the URL printed by the server in the phone's browser.
3. Turn the phone **landscape** and tap the ⛶ button for fullscreen
   (it also tries to lock landscape).
4. Play. Keep the terminal open; Ctrl+C stops the pad.

## 4. Mobile app (optional)

The native app lives in [`mobile/`](mobile/) and uses the same laptop server.
App-specific setup, controls, layout editor and tests are in
[`mobile/README.md`](mobile/README.md).

**Android** (build on Linux or macOS):

```bash
cd mobile
flutter pub get
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

**iPhone** needs macOS and Xcode:

```bash
cd mobile
flutter run          # simulator or device
flutter build ipa --release
```

Connect from the app:

1. Start `./start.sh` on the laptop and read the **Mobile app** address.
2. Wi-Fi: enter that IP and port **8081**, then tap **CONNECT**.
3. Android USB: enable USB tethering, then use the laptop's `192.168.42.x`
   address on port **8081**.
4. iPhone: Wi-Fi only. Accept the iOS **Local Network** prompt.

The app is landscape locked and immersive. It has the same pad and press
behaviour as the web version, plus haptics, a dead-zone control, per-control
sizes and face-button pinch spacing, a centered drag/pinch layout editor, a
custom color or photo background with an outlined “Boy Alone” mark, and live
link status with round-trip time. The web page and the app share one virtual
pad, so use one controller at a time.

Detailed app notes and the UDP protocol are in [`MOBILE-APP.md`](MOBILE-APP.md)
and [`mobile/README.md`](mobile/README.md).

## Controls

| Phone control | PSP button | PPSSPP pad code |
|---|---|---|
| ✕ cross | Cross | A |
| ○ circle | Circle | B |
| □ square | Square | X |
| △ triangle | Triangle | Y |
| L / R shoulders | L / R | LB / RB |
| D-pad | D-pad | hat |
| ANALOG nub | Analog stick | left X/Y |
| START / SELECT | Start / Select | Start / Back |
| MENU | pause menu | Guide |
| FF / REW | fast-forward / rewind | L3 / R3 |

The analog nub sends true analog values, with a small dead zone.

## Customizing the pad

Tap the ⚙ button next to fullscreen to open **Controls**:

- **All controls** scales the whole layout. Each control (D-pad, analog,
  face buttons, L, R, Start/hotkeys) also has its own size slider. The app also
  exposes D-pad and face-button spacing, dead zone, haptics and live link
  diagnostics.
- **Edit layout** enters drag mode. Tap a control to select it (it gets a
  bright outline), drag it anywhere, and use the bottom slider to resize just
  that control. **Reset** restores the default layout.
- Everything is stored on the phone (`localStorage` in the browser,
  `shared_preferences` in the app), so your layout survives restarts. It is per
  device — a different phone keeps its own layout.
- Buttons grow when pressed and grow a little more when held, like the
  PPSSPP Gold touch controls.

## Notes & troubleshooting

**The phone can't open the page**

- Confirm both devices are on the same network. The IP printed is the PC's
  Wi-Fi address (`ip -4 addr` shows it too).
- Test from the PC: `curl http://127.0.0.1:8080/health`
- If a firewall is active, allow TCP port 8080.
- Many Android hotspots isolate clients; if the PC is on the phone's hotspot,
  the phone itself can usually reach the PC at its hotspot IP. If not, put both
  on a normal Wi-Fi router.

**The mobile app says "No response from the laptop"**

- Use the exact IP printed next to **Mobile app** and port **8081**.
- Allow UDP 8081 in the firewall, for example
  `sudo ufw allow 8081/udp`.
- On iPhone, accept the **Local Network** prompt the first time. iPhone is
  Wi-Fi only.
- On Android USB, enable USB tethering and use the laptop's `192.168.42.x`
  address, not the Wi-Fi address.
- Stop the web pad before using the app (they share one virtual pad).
- Check the server terminal: it prints `app connected from …` on the first
  packet and releases all inputs if packets stop for 400 ms.
- Run `curl http://127.0.0.1:8080/health` on the laptop to confirm the bridge:
  `udp_port` should be `8081` and `udp_active` turns true while the app is open.

**PPSSPP doesn't react to the pad**

- Start the pad server **before** PPSSPP, or restart PPSSPP after starting it.
- Check the snap interface: `snap connections ppsspp-emu | grep joystick`
  (it should be connected; `sudo ./setup-uinput.sh` fixes this).
- Check the virtual device exists:
  `ls -l /dev/input/event*` — a new `Microsoft X-Box 360 pad` device appears
  while the server runs.
- In PPSSPP: **Settings → Controls → Control Mapping**. The server patches
  `controls.ini` so it should already work; if L/R are dead, map them manually
  to the pad's shoulder buttons, or delete
  `~/snap/ppsspp-emu/common/.config/ppsspp/PSP/SYSTEM/controls.ini` and let
  PPSSPP regenerate it.
- Only one joystick may be present for the saved `10-*` mapping to apply. If you
  plug in another controller, remove it or remap in PPSSPP.

**Nothing happens after the one-time setup**

Remove and reconnect the phone in the browser, or restart the server. The
terminal logs every connection and button press.

**I want to test without creating a virtual gamepad**

```bash
./start.sh --dry-run --no-fix-controls
```

This serves the page and logs presses to the terminal without creating a
virtual gamepad (works without sudo). Drop `--no-fix-controls` if you still
want the PPSSPP mapping patch.

**Uninstall the system bits**

```bash
sudo rm /etc/udev/rules.d/99-ppsspp-phone-pad.rules \
        /etc/modules-load.d/uinput.conf
sudo udevadm control --reload-rules
```

## Development

Server-side UDP tests (needs the `websockets` package):

```bash
python3 -m unittest discover -s tests -v
```

Mobile tests and static analysis:

```bash
cd mobile
flutter test
flutter analyze
```

## Security

The web page and the UDP bridge have no password and listen on all interfaces.
Anyone on the same LAN who can reach TCP 8080 or UDP 8081 can control the pad.
Use it on a trusted home network and stop the server (Ctrl+C or the systemd
service) when you're done.
