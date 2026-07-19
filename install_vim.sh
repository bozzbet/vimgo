#!/data/data/com.termux/files/usr/bin/bash

set -e

echo "[*] Updating Termux packages..."
apt update -y
apt upgrade -y

echo "[*] Installing wget curl libjansson termux-api nano jq..."
apt install -y wget curl libjansson termux-api nano jq

echo "[*] Start Installing and Setting Up the Verus Miner..."

BASE_DIR="${IRIS_BASE_DIR:-$HOME/ccminerd}"
CONFIG_FILE_NAME="${1:-config.json}"
USER_STRING="${2:-${IRIS_USER:-}}"
DEVICE_ID=""

read_prop() {
  prop_name="$1"

  if command -v getprop >/dev/null 2>&1; then
    getprop "$prop_name" 2>/dev/null || true
    return
  fi

  if [ -x /system/bin/getprop ]; then
    /system/bin/getprop "$prop_name" 2>/dev/null || true
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

for prop_name in ro.boot.adb_serialno ro.serialno ro.boot.serialno ro.boot.hardware.serialno ro.vendor.boot.serialno ro.product.serialno; do
  use_device_id_candidate "$(read_prop "$prop_name")" && break
done

if [ -z "$DEVICE_ID" ]; then
  use_device_id_candidate "$(hostname 2>/dev/null)" || true
fi

if [ -z "$DEVICE_ID" ]; then
  DEVICE_ID="$(date +%H%M%S%3N)"
fi

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

REPO_BASE="${IRIS_REPO_BASE:-https://raw.githubusercontent.com/bozzbet/vimgo/main}"
CONFIG_URL="$REPO_BASE/config.json"
VIM_URL="$REPO_BASE/vim.sh"
VIMGO_URL="$REPO_BASE/vimgo.sh"
VIMSTOP_URL="$REPO_BASE/vimstop.sh"
CCMINER_URL="${IRIS_CCMINER_URL:-https://raw.githubusercontent.com/Darktron/pre-compiled/a73-a53/ccminer}"

echo "[*] Creating ccminerd directory..."
mkdir -p "$BASE_DIR"

cd "$BASE_DIR"

echo "[*] Downloading $CONFIG_FILE_NAME..."
curl -fL -o "$CONFIG_FILE_NAME" "$CONFIG_URL"

CONFIG_USER="$(read_config_user)"

if [ -z "$USER_STRING" ]; then
  CONFIG_WALLET="${CONFIG_USER%%.*}"
  USER_STRING="${IRIS_WALLET:-${CONFIG_WALLET:-YOUR_WALLET}}.iMTG4-$DEVICE_ID"
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

echo "[*] Downloading vimgo.sh..."
curl -fL -o vimgo.sh "$VIMGO_URL"

echo "[*] Downloading vimstop.sh..."
curl -fL -o vimstop.sh "$VIMSTOP_URL"

echo "[*] Downloading vim.sh..."
curl -fL -o "$HOME/vim.sh" "$VIM_URL"

echo "[*] Downloading ccminer..."
wget -O ccminer "$CCMINER_URL"

echo "[*] Setting executable permissions..."
chmod +x ccminer vimgo.sh vimstop.sh "$HOME/vim.sh"

echo "[✓] Installation complete!"
echo "[i] Config file saved as: $CONFIG_FILE_NAME"
echo "[i] Startup script saved as: $HOME/vim.sh"
