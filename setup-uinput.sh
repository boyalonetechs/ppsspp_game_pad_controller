
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Please run this with sudo:  sudo $0" >&2
  exit 1
fi

REAL_USER="${SUDO_USER:-}"
if [[ -z "${REAL_USER}" || "${REAL_USER}" == "root" ]]; then
  echo "Run this via sudo from your normal desktop user account." >&2
  exit 1
fi

echo "[1/5] Loading the uinput kernel module…"
echo "uinput" > /etc/modules-load.d/uinput.conf
modprobe uinput

echo "[2/5] Installing udev rule for /dev/uinput…"
cat > /etc/udev/rules.d/99-ppsspp-phone-pad.rules <<EOF
# Virtual gamepad used by the phone pad (see ~/psp-phone-pad)
KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess", GROUP="input", MODE="0660", RUN+="/usr/bin/setfacl -m u:${REAL_USER}:rw /dev/uinput"
EOF

udevadm control --reload-rules
udevadm trigger --action=change /sys/devices/virtual/misc/uinput 2>/dev/null || \
  udevadm trigger --subsystem-match=misc --sysname-match=uinput || true
sleep 1

echo "[3/5] Checking access for user '${REAL_USER}'…"
acl_grants_access() {
  getfacl -p /dev/uinput 2>/dev/null | grep -q "^user:${REAL_USER}:rw"
}
user_can_write() {
  if command -v runuser >/dev/null 2>&1 && \
     runuser -u "${REAL_USER}" -- test -w /dev/uinput 2>/dev/null; then
    return 0
  fi
  acl_grants_access
}

for _ in 1 2 3 4 5; do
  user_can_write && break
  sleep 1
done

if ! user_can_write; then
  echo "      uaccess ACL did not apply — adding a direct ACL as a fallback."
  setfacl -m "u:${REAL_USER}:rw" /dev/uinput 2>/dev/null || chmod 0666 /dev/uinput
fi

if ! user_can_write; then
  echo "ERROR: ${REAL_USER} still cannot write to /dev/uinput." >&2
  ls -l /dev/uinput >&2
  getfacl -p /dev/uinput >&2 || true
  exit 1
fi

echo "[4/5] Access OK:"
ls -l /dev/uinput
getfacl /dev/uinput 2>/dev/null | sed 's/^/      /' || true

echo "[5/5] Checking the PPSSPP snap's joystick interface…"
if command -v snap >/dev/null 2>&1; then
  if snap connections ppsspp-emu 2>/dev/null | grep -q 'joystick.*:joystick'; then
    echo "      OK: ppsspp-emu:joystick is already connected."
  else
    echo "      Connecting ppsspp-emu:joystick…"
    snap connect ppsspp-emu:joystick :joystick || true
  fi
fi

echo
echo "Setup complete. Start the pad with:"
echo "  cd $(cd "$(dirname "$0")" && pwd)"
echo "  ./start.sh"
