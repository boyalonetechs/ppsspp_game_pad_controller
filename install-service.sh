#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT="$UNIT_DIR/psp-phone-pad.service"

if [[ ! -e /dev/uinput ]]; then
  echo "ERROR: /dev/uinput is missing. Run: sudo $ROOT/setup-uinput.sh" >&2
  exit 1
fi

if [[ ! -w /dev/uinput ]]; then
  echo "ERROR: $USER cannot write /dev/uinput. Run: sudo $ROOT/setup-uinput.sh" >&2
  exit 1
fi

mkdir -p "$UNIT_DIR"
sed "s|@ROOT@|$ROOT|g" "$ROOT/systemd/psp-phone-pad.service.in" > "$UNIT"

systemctl --user daemon-reload
systemctl --user enable --now psp-phone-pad.service
systemctl --user --no-pager status psp-phone-pad.service || true

echo
echo "Service installed from $ROOT"
echo "Logs: journalctl --user -u psp-phone-pad -f"
echo "Stop: systemctl --user disable --now psp-phone-pad.service"
