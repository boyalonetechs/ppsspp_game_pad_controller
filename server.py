#!/usr/bin/env python3
"""
Phone -> PC virtual gamepad for PPSSPP.

Serves a PSP-style touch controller to your phone over Wi-Fi and injects it
into Linux as a virtual Xbox 360 controller through /dev/uinput.  PPSSPP
(including the snap build) sees it as a normal gamepad, analog stick included.

Usage:
    python3 server.py                 # serve on http://<your-ip>:8080
    python3 server.py --launch        # also launch the PPSSPP snap
    python3 server.py --dry-run       # no /dev/uinput, just log input
"""

from __future__ import annotations

import argparse
import asyncio
import ctypes
import fcntl
import json
import os
import socket
import struct
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

from websockets.asyncio.server import serve
from websockets.http11 import Headers, Response


# Linux uinput (no external Python packages required)

UINPUT_MAX_NAME_SIZE = 80


class _InputId(ctypes.Structure):
    _fields_ = [
        ("bustype", ctypes.c_uint16),
        ("vendor", ctypes.c_uint16),
        ("product", ctypes.c_uint16),
        ("version", ctypes.c_uint16),
    ]


class _UinputUserDev(ctypes.Structure):
    _fields_ = [
        ("name", ctypes.c_char * UINPUT_MAX_NAME_SIZE),
        ("id", _InputId),
        ("ff_effects_max", ctypes.c_uint32),
        ("absmax", ctypes.c_int32 * 64),
        ("absmin", ctypes.c_int32 * 64),
        ("absfuzz", ctypes.c_int32 * 64),
        ("absflat", ctypes.c_int32 * 64),
    ]


def _ioc(direction: int, type_: str, nr: int, size: int) -> int:
    return (direction << 30) | (size << 16) | (ord(type_) << 8) | nr


def _io(type_: str, nr: int) -> int:
    return _ioc(0, type_, nr, 0)


def _iow(type_: str, nr: int, size: int) -> int:
    return _ioc(1, type_, nr, size)


UI_DEV_CREATE = _io("U", 1)
UI_DEV_DESTROY = _io("U", 2)
UI_SET_EVBIT = _iow("U", 100, 4)
UI_SET_KEYBIT = _iow("U", 101, 4)
UI_SET_ABSBIT = _iow("U", 103, 4)

EV_SYN = 0x00
EV_KEY = 0x01
EV_ABS = 0x03
SYN_REPORT = 0x00

ABS_X = 0x00
ABS_Y = 0x01
ABS_Z = 0x02
ABS_RX = 0x03
ABS_RY = 0x04
ABS_RZ = 0x05
ABS_HAT0X = 0x10
ABS_HAT0Y = 0x11

BTN_A = 0x130
BTN_B = 0x131
BTN_X = 0x133
BTN_Y = 0x134
BTN_TL = 0x136
BTN_TR = 0x137
BTN_SELECT = 0x13A
BTN_START = 0x13B
BTN_MODE = 0x13C
BTN_THUMBL = 0x13D
BTN_THUMBR = 0x13E

BUTTON_CODES = {
    "cross": BTN_A,
    "circle": BTN_B,
    "square": BTN_X,
    "triangle": BTN_Y,
    "l": BTN_TL,
    "r": BTN_TR,
    "select": BTN_SELECT,
    "start": BTN_START,
    "guide": BTN_MODE,
    "l3": BTN_THUMBL,
    "r3": BTN_THUMBR,
}

_ABS_SPECS = [
    (ABS_X, -32768, 32767),
    (ABS_Y, -32768, 32767),
    (ABS_Z, 0, 255),
    (ABS_RX, -32768, 32767),
    (ABS_RY, -32768, 32767),
    (ABS_RZ, 0, 255),
    (ABS_HAT0X, -1, 1),
    (ABS_HAT0Y, -1, 1),
]


class VirtualPad:
    """A uinput Xbox 360-compatible gamepad."""
    VENDOR = 0x045E       
    PRODUCT = 0x028E      
    VERSION = 0x0104
    NAME = b"Microsoft X-Box 360 pad"

    def __init__(self, dry_run: bool = False) -> None:
        self.dry_run = dry_run
        self.fd: int | None = None
        self._buttons: dict[str, bool] = {name: False for name in BUTTON_CODES}
        self._axis = (0, 0)
        self._hat = (0, 0)
        if not dry_run:
            self._create()

    # -- setup -------------------------------------------------------------
    def _create(self) -> None:
        try:
            fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
        except PermissionError as exc:
            raise RuntimeError(
                "No write access to /dev/uinput.\n"
                "Run the one-time setup first:  sudo ./setup-uinput.sh"
            ) from exc
        except FileNotFoundError as exc:
            raise RuntimeError(
                "/dev/uinput does not exist. Try:  sudo modprobe uinput"
            ) from exc

        try:
            fcntl.ioctl(fd, UI_SET_EVBIT, EV_KEY)
            fcntl.ioctl(fd, UI_SET_EVBIT, EV_ABS)
            for code in BUTTON_CODES.values():
                fcntl.ioctl(fd, UI_SET_KEYBIT, code)
            for code, lo, hi in _ABS_SPECS:
                fcntl.ioctl(fd, UI_SET_ABSBIT, code)

            dev = _UinputUserDev()
            dev.name = self.NAME
            dev.id = _InputId(0x0003, self.VENDOR, self.PRODUCT, self.VERSION)  # BUS_USB
            dev.ff_effects_max = 0
            for code, lo, hi in _ABS_SPECS:
                dev.absmin[code] = lo
                dev.absmax[code] = hi
                dev.absfuzz[code] = 0
                dev.absflat[code] = 0

            os.write(fd, ctypes.string_at(ctypes.byref(dev), ctypes.sizeof(dev)))
            fcntl.ioctl(fd, UI_DEV_CREATE)
        except Exception:
            os.close(fd)
            raise

        self.fd = fd
        time.sleep(0.4)

        for code in (ABS_X, ABS_Y, ABS_RX, ABS_RY, ABS_Z, ABS_RZ):
            self._emit(EV_ABS, code, 0)
        self._emit(EV_ABS, ABS_HAT0X, 0)
        self._emit(EV_ABS, ABS_HAT0Y, 0)
        self._syn()

    def _emit(self, type_: int, code: int, value: int) -> None:
        if self.fd is None:
            return
        os.write(self.fd, struct.pack("@llHHi", 0, 0, type_, code, int(value)))

    def _syn(self) -> None:
        self._emit(EV_SYN, SYN_REPORT, 0)

    def set_button(self, name: str, down: bool) -> None:
        code = BUTTON_CODES.get(name)
        if code is None:
            return
        down = bool(down)
        if self._buttons.get(name) == down:
            return
        self._buttons[name] = down
        if self.dry_run:
            print(f"[dry-run] button {name} {'DOWN' if down else 'up'}", flush=True)
            return
        self._emit(EV_KEY, code, 1 if down else 0)
        self._syn()

    def set_axis(self, x: float, y: float) -> None:
        x = max(-1.0, min(1.0, float(x)))
        y = max(-1.0, min(1.0, float(y)))
        ix = int(round(x * 32767))
        iy = int(round(y * 32767))
        if (ix, iy) == self._axis:
            return
        old = self._axis
        self._axis = (ix, iy)
        if self.dry_run:
            print(f"[dry-run] axis {x:+.2f} {y:+.2f}", flush=True)
            return
        if ix != old[0]:
            self._emit(EV_ABS, ABS_X, ix)
        if iy != old[1]:
            self._emit(EV_ABS, ABS_Y, iy)
        self._syn()

    def set_hat(self, hx: int, hy: int) -> None:
        hx = max(-1, min(1, int(hx)))
        hy = max(-1, min(1, int(hy)))
        if (hx, hy) == self._hat:
            return
        old = self._hat
        self._hat = (hx, hy)
        if self.dry_run:
            print(f"[dry-run] hat {hx:+d} {hy:+d}", flush=True)
            return
        if hx != old[0]:
            self._emit(EV_ABS, ABS_HAT0X, hx)
        if hy != old[1]:
            self._emit(EV_ABS, ABS_HAT0Y, hy)
        self._syn()

    def release_all(self) -> None:
        if self.dry_run:
            return
        for name, down in self._buttons.items():
            if down:
                self._emit(EV_KEY, BUTTON_CODES[name], 0)
                self._buttons[name] = False
        self._emit(EV_ABS, ABS_X, 0)
        self._emit(EV_ABS, ABS_Y, 0)
        self._emit(EV_ABS, ABS_HAT0X, 0)
        self._emit(EV_ABS, ABS_HAT0Y, 0)
        self._axis = (0, 0)
        self._hat = (0, 0)
        self._syn()

    def close(self) -> None:
        if self.fd is None:
            return
        try:
            self.release_all()
        except OSError:
            pass
        try:
            fcntl.ioctl(self.fd, UI_DEV_DESTROY)
        except OSError:
            pass
        try:
            os.close(self.fd)
        except OSError:
            pass
        self.fd = None


PAD_FIX = {
    "L": ("10-193", "1-45"),
    "R": ("10-192", "1-51"),
}
HOTKEY_FIX = {
    "Pause": "10-4",            
    "Fast-forward": "10-106",   
    "Rewind": "10-107",         
}


def _controls_files() -> list[Path]:
    home = Path.home()
    candidates = [
        home / ".config/ppsspp/PSP/SYSTEM/controls.ini",
        home / "snap/ppsspp-emu/common/.config/ppsspp/PSP/SYSTEM/controls.ini",
        home / ".var/app/org.ppsspp.PPSSPP/config/ppsspp/PSP/SYSTEM/controls.ini",
    ]
    return [p for p in candidates if p.is_file()]


def _patch_controls_text(text: str) -> tuple[str, bool]:
    lines = text.splitlines()
    out: list[str] = []
    section = ""
    seen: set[str] = set()
    changed = False

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            section = stripped[1:-1]
        if section == "ControlMapping" and "=" in line and not stripped.startswith("#"):
            key, value = line.split("=", 1)
            key = key.strip()
            seen.add(key)
            tokens = [t.strip() for t in value.strip().split(",") if t.strip()]

            if key in PAD_FIX:
                pad_token, kbd_token = PAD_FIX[key]
                tokens = [t for t in tokens if not t.startswith("10-")]
                if kbd_token not in tokens:
                    tokens.insert(0, kbd_token)
                tokens.append(pad_token)
            elif key in HOTKEY_FIX:
                token = HOTKEY_FIX[key]
                if token not in tokens:
                    tokens.append(token)
            else:
                out.append(line)
                continue

            new_value = ",".join(tokens)
            new_line = f"{key} = {new_value}"
            if new_line != line:
                changed = True
            out.append(new_line)
            continue
        out.append(line)

    missing = [k for k in HOTKEY_FIX if k not in seen]
    if missing:
        if section == "ControlMapping":
            for key in missing:
                out.append(f"{key} = {HOTKEY_FIX[key]}")
                changed = True
        else:
            insert_at = next(
                (i for i, l in enumerate(out) if l.strip().startswith("[") and l.strip() != "[ControlMapping]"),
                len(out),
            )
            add = [f"{k} = {HOTKEY_FIX[k]}" for k in missing]
            out[insert_at:insert_at] = add
            changed = True

    return "\n".join(out) + ("\n" if text.endswith("\n") else ""), changed


def fix_controls() -> None:
    for path in _controls_files():
        try:
            original = path.read_text(encoding="utf-8-sig")
            patched, changed = _patch_controls_text(original)
            if not changed:
                print(f"controls: {path} already OK")
                continue
            stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
            backup = path.with_name(f"{path.name}.bak-{stamp}")
            backup.write_text(original, encoding="utf-8-sig")
            path.write_text(patched, encoding="utf-8-sig")
            print(f"controls: patched {path}  (backup: {backup.name})")
        except OSError as exc:
            print(f"controls: could not patch {path}: {exc}")


def ppsspp_running() -> bool:
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            cmd = (entry / "cmdline").read_bytes().replace(b"\x00", b" ").decode(errors="ignore")
        except OSError:
            continue
        if "PPSSPPSDL" in cmd:
            return True
    return False


HERE = Path(__file__).resolve().parent
INDEX_HTML = HERE / "index.html"


def _response(status: int, reason: str, body: bytes, content_type: str) -> Response:
    headers = Headers()
    headers["Content-Type"] = content_type
    headers["Content-Length"] = str(len(body))
    headers["Cache-Control"] = "no-store"
    return Response(status, reason, headers, body)


def local_ips() -> list[str]:
    ips: set[str] = set()
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            sock.connect(("8.8.8.8", 80))
            ips.add(sock.getsockname()[0])
        finally:
            sock.close()
    except OSError:
        pass
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            ips.add(info[4][0])
    except OSError:
        pass
    return sorted(ip for ip in ips if not ip.startswith("127."))


class Server:
    def __init__(self, pad: VirtualPad) -> None:
        self.pad = pad
        self.clients = 0

    async def handler(self, ws) -> None:
        peer = f"{ws.remote_address[0]}:{ws.remote_address[1]}" if ws.remote_address else "?"
        self.clients += 1
        print(f"* phone connected from {peer}  ({self.clients} client(s))", flush=True)
        pressed: set[str] = set()
        try:
            async for raw in ws:
                try:
                    msg = json.loads(raw)
                except (TypeError, ValueError):
                    continue
                if not isinstance(msg, dict):
                    continue

                kind = msg.get("t")
                if kind == "b":
                    name = str(msg.get("k", ""))
                    if name in BUTTON_CODES:
                        down = bool(msg.get("v"))
                        self.pad.set_button(name, down)
                        if down:
                            pressed.add(name)
                        else:
                            pressed.discard(name)
                elif kind == "ax":
                    try:
                        x = float(msg.get("x", 0.0))
                        y = float(msg.get("y", 0.0))
                    except (TypeError, ValueError):
                        continue
                    self.pad.set_axis(x, y)
                elif kind == "hat":
                    try:
                        hx = int(msg.get("x", 0))
                        hy = int(msg.get("y", 0))
                    except (TypeError, ValueError):
                        continue
                    self.pad.set_hat(hx, hy)
                elif kind == "ping":
                    await ws.send(json.dumps({"t": "pong", "ts": msg.get("ts")}))
        except Exception as exc:  # connection reset, etc.
            print(f"* phone disconnected ({exc.__class__.__name__})", flush=True)
        finally:
            for name in pressed:
                self.pad.set_button(name, False)
            self.pad.set_axis(0.0, 0.0)
            self.pad.set_hat(0, 0)
            self.clients -= 1
            print(f"* phone disconnected  ({max(self.clients, 0)} client(s))", flush=True)

    async def process_request(self, connection, request):
        path = request.path.split("?", 1)[0]
        if path in ("/", "/index.html"):
            try:
                body = INDEX_HTML.read_bytes()
            except OSError:
                return _response(500, "Internal Server Error", b"index.html missing", "text/plain; charset=utf-8")
            return _response(200, "OK", body, "text/html; charset=utf-8")
        if path == "/health":
            body = json.dumps(
                {
                    "ok": True,
                    "clients": self.clients,
                    "dry_run": self.pad.dry_run,
                    "uinput": self.pad.fd is not None,
                }
            ).encode()
            return _response(200, "OK", body, "application/json")
        if path == "/favicon.ico":
            return _response(204, "No Content", b"", "image/x-icon")
        if path == "/ws":
            return None
        return _response(404, "Not Found", b"not found", "text/plain; charset=utf-8")


def print_banner(port: int) -> None:
    ips = local_ips()
    print()
    print("  ┌──────────────────────────────────────────────┐")
    print("  │  PSP Phone Pad                               │")
    print("  └──────────────────────────────────────────────┘")
    if ips:
        for ip in ips:
            print(f"  Open on your phone:  http://{ip}:{port}")
    else:
        print(f"  Open on your phone:  http://<this-pc-ip>:{port}")
    print()
    print("  Phone and PC must be on the same Wi-Fi network.")
    print("  Keep this terminal open.  Press Ctrl+C to stop.")
    print()


async def amain(args: argparse.Namespace) -> None:
    print("Starting virtual Xbox 360 pad…")
    pad = VirtualPad(dry_run=args.dry_run)
    if pad.fd:
        print("Virtual pad created: Microsoft X-Box 360 pad (/dev/uinput)")
    elif pad.dry_run:
        print("Dry-run mode: input is only logged, no virtual device created.")

    if not args.no_fix_controls:
        if ppsspp_running():
            print("WARNING: PPSSPP is running and will overwrite controls.ini when it exits.")
            print("         Quit PPSSPP, then start it again after this server.")
        fix_controls()

    server = Server(pad)
    try:
        async with serve(
            server.handler,
            args.host,
            args.port,
            process_request=server.process_request,
            ping_interval=20,
            ping_timeout=20,
            max_size=1 << 20,
        ):
            print_banner(args.port)
            if args.launch:
                async def launch() -> None:
                    await asyncio.sleep(1.5)
                    if ppsspp_running():
                        print("PPSSPP is already running; not launching another instance.")
                        return
                    print("Launching PPSSPP…")
                    try:
                        subprocess.Popen(
                            ["snap", "run", "ppsspp-emu.ppsspp-sdl"],
                            start_new_session=True,
                        )
                    except OSError as exc:
                        print(f"Could not launch PPSSPP: {exc}")

                asyncio.create_task(launch())
            await asyncio.Event().wait()
    finally:
        pad.close()
        print("\nVirtual pad removed. Bye.")


def main() -> int:
    parser = argparse.ArgumentParser(description="Phone gamepad for PPSSPP")
    parser.add_argument("--host", default="0.0.0.0", help="listen address (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=8080, help="listen port (default: 8080)")
    parser.add_argument("--dry-run", action="store_true", help="don't create /dev/uinput device")
    parser.add_argument("--no-fix-controls", action="store_true", help="don't touch PPSSPP controls.ini")
    parser.add_argument("--launch", action="store_true", help="launch the PPSSPP snap after starting")
    args = parser.parse_args()

    try:
        asyncio.run(amain(args))
    except KeyboardInterrupt:
        pass
    except RuntimeError as exc:
        print(f"\nERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
