import asyncio
import time
import unittest
from contextlib import redirect_stdout
from io import StringIO
from unittest import mock

import server


def make_packet(
    seq=7,
    buttons=0,
    hat=5,
    left=(0, 0),
    right=(0, 0),
    triggers=(0, 0),
):
    return server.UDP_PACKET.pack(
        server.UDP_MAGIC,
        seq,
        buttons,
        hat,
        left[0],
        left[1],
        right[0],
        right[1],
        triggers[0],
        triggers[1],
    )


class PacketTests(unittest.TestCase):
    def test_packet_is_nineteen_bytes(self):
        self.assertEqual(server.UDP_PACKET.size, 19)

    def test_decodes_full_state(self):
        decoded = server._decode_packet(
            make_packet(
                seq=513,
                buttons=0b100101,
                hat=0,
                left=(32767, -32767),
                right=(-1234, 4321),
                triggers=(12, 200),
            )
        )
        self.assertIsNotNone(decoded)
        self.assertEqual(decoded["seq"], 513)
        self.assertEqual(decoded["buttons"], 0b100101)
        self.assertEqual(decoded["hat"], 0)
        self.assertEqual(decoded["left"], (1.0, -1.0))
        self.assertEqual(decoded["right"], (-1234 / 32767.0, 4321 / 32767.0))
        self.assertEqual(decoded["triggers"], (12, 200))

    def test_rejects_short_packet(self):
        self.assertIsNone(server._decode_packet(b"PSP1"))

    def test_rejects_wrong_magic(self):
        data = bytearray(make_packet())
        data[:4] = b"NOPE"
        self.assertIsNone(server._decode_packet(bytes(data)))

    def test_echo_layout(self):
        self.assertEqual(server.UDP_ECHO.size, 6)
        self.assertEqual(server.UDP_ECHO.unpack(server.UDP_ECHO.pack(b"PSP1", 4096)), (b"PSP1", 4096))


class PadTests(unittest.TestCase):
    def setUp(self):
        self.pad = server.VirtualPad(dry_run=True)

    def apply(self, *args):
        with redirect_stdout(StringIO()):
            self.pad.apply_udp_state(*args)

    def test_applies_buttons_hat_axes_and_triggers(self):
        buttons = (1 << 2) | (1 << 9)
        self.apply(buttons, 10, (0.5, -0.25), (-0.5, 0.75), (12, 34))
        self.assertTrue(self.pad._buttons["cross"])
        self.assertTrue(self.pad._buttons["l3"])
        self.assertFalse(self.pad._buttons["circle"])
        self.assertEqual(self.pad._hat, (1, 1))
        self.assertEqual(self.pad._axis, (round(0.5 * 32767), round(-0.25 * 32767)))
        self.assertEqual(self.pad._right_axis, (round(-0.5 * 32767), round(0.75 * 32767)))
        self.assertEqual(self.pad._triggers, (12, 34))

    def test_hat_encoding_round_trips(self):
        for x in (-1, 0, 1):
            for y in (-1, 0, 1):
                self.apply(0, (x + 1) | ((y + 1) << 2), (0, 0), (0, 0), (0, 0))
                self.assertEqual(self.pad._hat, (x, y))

    def test_release_clears_every_control(self):
        self.apply((1 << 0) | (1 << 10), 0, (0.8, 0.8), (-0.8, -0.8), (200, 100))
        with redirect_stdout(StringIO()):
            self.pad.release_all()
        self.assertFalse(any(self.pad._buttons.values()))
        self.assertEqual(self.pad._axis, (0, 0))
        self.assertEqual(self.pad._right_axis, (0, 0))
        self.assertEqual(self.pad._triggers, (0, 0))
        self.assertEqual(self.pad._hat, (0, 0))


class BridgeTests(unittest.IsolatedAsyncioTestCase):
    async def test_watchdog_releases_after_timeout(self):
        pad = server.VirtualPad(dry_run=True)
        with redirect_stdout(StringIO()):
            pad.set_button("cross", True)
            pad.set_axis(0.5, 0.5)
        bridge = server.UdpBridge(pad, 0)
        bridge.active = True
        bridge.last_rx = time.monotonic() - 1
        with mock.patch.object(server, "UDP_TIMEOUT", 0.01):
            with redirect_stdout(StringIO()):
                task = asyncio.create_task(server.udp_watchdog(pad, bridge))
                await asyncio.sleep(0.12)
                task.cancel()
                with self.assertRaises(asyncio.CancelledError):
                    await task
        self.assertFalse(bridge.active)
        self.assertFalse(pad._buttons["cross"])
        self.assertEqual(pad._axis, (0, 0))
