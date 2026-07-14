#!/usr/bin/env bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "[*] Start Installing and Setting Up the Raspberry Pi Verus Miner..."

VRSC_DIR="${IRIS_VRSC_DIR:-$HOME/vrsc}"
BASE_DIR="${IRIS_BASE_DIR:-$VRSC_DIR/ccminerd}"
CONFIG_FILE_NAME="${1:-config.json}"
USER_STRING="${2:-${IRIS_USER:-}}"
REPO_BASE="${IRIS_REPO_BASE:-https://raw.githubusercontent.com/bozzbet/vimgo/main}"
CONFIG_URL="$REPO_BASE/config.json"
CCMINER_URL="${IRIS_CCMINER_URL:-https://raw.githubusercontent.com/Darktron/pre-compiled/a73-a53/ccminer}"
DEVICE_ID=""

require_linux() {
  if [ "$(uname -s)" != "Linux" ]; then
    echo "[!] This installer is for Raspberry Pi OS / Debian Linux." >&2
    exit 1
  fi
}

run_apt() {
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "[!] apt-get was not found. This installer expects Raspberry Pi OS or Debian." >&2
    exit 1
  fi

  if [ "$(id -u)" -eq 0 ]; then
    apt-get update -y
    apt-get install -y curl wget jq ca-certificates libjansson4 procps
  elif command -v sudo >/dev/null 2>&1; then
    sudo apt-get update -y
    sudo apt-get install -y curl wget jq ca-certificates libjansson4 procps
  else
    echo "[!] sudo was not found. Run this installer as root or install sudo." >&2
    exit 1
  fi
}

use_device_id_candidate() {
  candidate="$(printf '%s' "$1" | tr -d '[:space:]')"
  candidate="$(printf '%s' "$candidate" | tr -cd 'A-Za-z0-9')"

  case "$candidate" in
    ""|localhost|LOCALHOST|unknown|UNKNOWN)
      return 1
      ;;
  esac

  DEVICE_ID="$candidate"
  return 0
}

detect_device_id() {
  if [ -r /proc/device-tree/serial-number ]; then
    use_device_id_candidate "$(tr -d '\0' </proc/device-tree/serial-number)" && return
  fi

  if [ -r /proc/cpuinfo ]; then
    cpu_serial="$(awk -F ': ' '/^Serial[[:space:]]*/ {print $2; exit}' /proc/cpuinfo)"
    use_device_id_candidate "$cpu_serial" && return
  fi

  use_device_id_candidate "$(hostname 2>/dev/null)" && return
  DEVICE_ID="$(date +%H%M%S%3N)"
}

update_config_user() {
  if command -v jq >/dev/null 2>&1; then
    tmp_config="$(mktemp)"
    jq --arg user "$USER_STRING" '.user = $user' "$CONFIG_FILE_NAME" > "$tmp_config"
    mv "$tmp_config" "$CONFIG_FILE_NAME"
  else
    sed -i -E "s#\"user\"[[:space:]]*:[[:space:]]*\"[^\"]*\"#\"user\": \"$USER_STRING\"#" "$CONFIG_FILE_NAME"
  fi
}

read_config_user() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.user // empty' "$CONFIG_FILE_NAME" 2>/dev/null || true
  else
    sed -n -E 's#.*"user"[[:space:]]*:[[:space:]]*"([^"]*)".*#\1#p' "$CONFIG_FILE_NAME" | head -n 1
  fi
}

write_pi_scripts() {
  cat > "$BASE_DIR/start.sh" <<'SCRIPT'
#!/usr/bin/env bash

set -euo pipefail

VRSC_DIR="${IRIS_VRSC_DIR:-$HOME/vrsc}"
CCMINER_DIR="${IRIS_BASE_DIR:-$VRSC_DIR/ccminerd}"
CONFIG_FILE_NAME="${1:-}"

resolve_config_file() {
  if [ -n "$CONFIG_FILE_NAME" ]; then
    if [ -f "$CONFIG_FILE_NAME" ]; then
      printf '%s\n' "$CONFIG_FILE_NAME"
      return 0
    fi
    if [ -f "$CCMINER_DIR/$CONFIG_FILE_NAME" ]; then
      printf '%s\n' "$CCMINER_DIR/$CONFIG_FILE_NAME"
      return 0
    fi
  fi

  if [ -f "$CCMINER_DIR/config.json" ]; then
    printf '%s\n' "$CCMINER_DIR/config.json"
    return 0
  fi

  config_candidate="$(find "$CCMINER_DIR" -maxdepth 1 -type f \( -name '*.json' -o -name '*.conf' -o -name '*.cfg' \) 2>/dev/null | sort | head -n 1)"
  if [ -n "$config_candidate" ]; then
    printf '%s\n' "$config_candidate"
    return 0
  fi

  return 1
}

mkdir -p "$CCMINER_DIR"
cd "$CCMINER_DIR"

CONFIG_FILE="$(resolve_config_file)" || {
  echo "No miner config file found. Expected config.json or another .json/.conf/.cfg file in $CCMINER_DIR." >&2
  exit 1
}

exec ./ccminer -c "$CONFIG_FILE"
SCRIPT

  cat > "$BASE_DIR/stop.sh" <<'SCRIPT'
#!/usr/bin/env bash

set -euo pipefail

if ! pgrep -x ccminer >/dev/null 2>&1; then
  echo "ccminer is not running."
  exit 0
fi

pkill -INT -x ccminer

for _ in 1 2 3 4 5; do
  if ! pgrep -x ccminer >/dev/null 2>&1; then
    echo "ccminer stopped."
    exit 0
  fi
  sleep 1
done

pkill -KILL -x ccminer
echo "ccminer force stopped."
SCRIPT

  cat > "$VRSC_DIR/start.sh" <<'SCRIPT'
#!/usr/bin/env bash

set -euo pipefail

VRSC_DIR="${IRIS_VRSC_DIR:-$HOME/vrsc}"
CCMINER_DIR="${IRIS_BASE_DIR:-$VRSC_DIR/ccminerd}"

exec "$CCMINER_DIR/start.sh" "$@"
SCRIPT

  cat > "$VRSC_DIR/stop.sh" <<'SCRIPT'
#!/usr/bin/env bash

set -euo pipefail

VRSC_DIR="${IRIS_VRSC_DIR:-$HOME/vrsc}"
CCMINER_DIR="${IRIS_BASE_DIR:-$VRSC_DIR/ccminerd}"

exec "$CCMINER_DIR/stop.sh" "$@"
SCRIPT
}

require_linux

ARCH="$(uname -m)"
case "$ARCH" in
  aarch64|arm64|armv7l|armv8l)
    echo "[i] Detected ARM Linux architecture: $ARCH"
    ;;
  *)
    echo "[!] Warning: detected architecture '$ARCH'. The default ccminer binary is intended for ARM Raspberry Pi systems." >&2
    ;;
esac

echo "[*] Updating packages and installing dependencies..."
run_apt

detect_device_id

if [ -d "$VRSC_DIR" ]; then
  echo "[i] vrsc directory exists: $VRSC_DIR"
else
  echo "[*] Creating vrsc directory: $VRSC_DIR"
  mkdir -p "$VRSC_DIR"
fi

echo "[*] Creating ccminerd directory inside vrsc..."
mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

echo "[*] Downloading $CONFIG_FILE_NAME..."
curl -fL -o "$CONFIG_FILE_NAME" "$CONFIG_URL"

CONFIG_USER="$(read_config_user)"

if [ -z "$USER_STRING" ]; then
  CONFIG_WALLET="${CONFIG_USER%%.*}"
  USER_STRING="${IRIS_WALLET:-${CONFIG_WALLET:-YOUR_WALLET}}.PiVim-$DEVICE_ID"
fi

if [ -n "$USER_STRING" ]; then
  echo "[i] Device ID: $DEVICE_ID"
  echo "[i] Original config user: ${CONFIG_USER:-none}"
  update_config_user
  UPDATED_CONFIG_USER="$(read_config_user)"

  if [ "$UPDATED_CONFIG_USER" != "$USER_STRING" ]; then
    echo "[!] Failed to update config user. Expected: $USER_STRING" >&2
    echo "[!] Actual: ${UPDATED_CONFIG_USER:-none}" >&2
    exit 1
  fi

  echo "[i] Updated config user: $UPDATED_CONFIG_USER"
fi

echo "[*] Downloading ccminer..."
wget -O ccminer "$CCMINER_URL"

echo "[*] Writing Raspberry Pi startup scripts..."
write_pi_scripts

echo "[*] Setting executable permissions..."
chmod +x ccminer "$BASE_DIR/start.sh" "$BASE_DIR/stop.sh" "$VRSC_DIR/start.sh" "$VRSC_DIR/stop.sh"

echo "[✓] Installation complete!"
echo "[i] Config file saved as: $BASE_DIR/$CONFIG_FILE_NAME"
echo "[i] Miner files saved in: $BASE_DIR"
echo "[i] Startup script saved as: $VRSC_DIR/start.sh"
echo "[i] Stop script saved as: $VRSC_DIR/stop.sh"
echo "[i] Start miner with: $VRSC_DIR/start.sh $CONFIG_FILE_NAME"
echo "[i] Stop miner with: $VRSC_DIR/stop.sh"
