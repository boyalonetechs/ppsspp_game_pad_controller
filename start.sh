

set -euo pipefail
cd "$(dirname "$0")"

DRY_RUN=0
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRY_RUN=1
  fi
done

if [[ ${DRY_RUN} -eq 0 ]]; then
  if [[ ! -e /dev/uinput ]]; then
    echo "ERROR: /dev/uinput is missing. Run:  sudo ./setup-uinput.sh" >&2
    exit 1
  fi
  if [[ ! -w /dev/uinput ]]; then
    echo "ERROR: you do not have write access to /dev/uinput." >&2
    echo "Run the one-time setup first:  sudo $(pwd)/setup-uinput.sh" >&2
    exit 1
  fi
fi

exec python3 -u server.py "$@"
