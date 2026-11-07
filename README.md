# PSP Phone Pad

Use your phone as a wireless PSP controller for PPSSPP on  Linux machines.

The phone opens a web page — no app to install — and the PC turns its touches
into a real virtual **Xbox 360 gamepad** (`/dev/uinput`). PPSSPP sees a normal
controller with a working analog stick, so every game works, not just
keyboard-mapped ones.

```
phone browser  ──Wi-Fi──►  server.py  ──uinput──►  virtual Xbox 360 pad  ──►  PPSSPP
```

## What you need

- Linux with `/dev/uinput` (machine: Ubuntu 26.04 ✓)
- Python 3 with the `websockets` package (already installed: 17.2 ✓)
- PPSSPP — you already have the **`ppsspp-emu` snap** installed ✓
- Phone and PC on the **same Wi-Fi network** (or the phone's hotspot)
- One-time `sudo` for the uinput permission setup

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
Open on your phone:  http://192.168.43.120:8080
```

Start PPSSPP **after** this server (the server fixes two PPSSPP button
mappings on startup; if PPSSPP was already running, quit and reopen it).

Shortcut — start the server and launch PPSSPP together:

```bash
./start.sh --launch
```

## 3. On the phone

1. Connect the phone to the same Wi-Fi / hotspot as the PC.
2. Open the URL printed by the server in the phone's browser.
3. Turn the phone **landscape** and tap the ⛶ button for fullscreen
   (it also tries to lock landscape).
4. Play. Keep the terminal open; Ctrl+C stops the pad.

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
  face buttons, L, R, Start/hotkeys) also has its own size slider.
- **Edit layout** enters drag mode. Tap a control to select it (it gets a
  bright outline), drag it anywhere, and use the bottom slider to resize just
  that control. **Reset** restores the default layout.
- Everything is stored in the phone browser (`localStorage`), so your layout
  survives reloads. It is per device — a different phone keeps its own layout.
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

**I want to test without touching the system**

```bash
./start.sh --dry-run
```

This serves the page and logs presses to the terminal without creating a
virtual gamepad (works without sudo).

**Uninstall the system bits**

```bash
sudo rm /etc/udev/rules.d/99-ppsspp-phone-pad.rules \
        /etc/modules-load.d/uinput.conf
sudo udevadm control --reload-rules
```

## Security

The web page has no password and listens on all interfaces. Anyone on the same
LAN who opens the URL can control the pad. Use it on a trusted home network and
stop the server (Ctrl+C) when you're done.
