#!/data/data/com.termux/files/usr/bin/bash

set -e

echo "[*] Updating Termux packages..."
apt update -y
apt upgrade -y

echo "[*] Installing wget curl libjansson termux-api nano jq..."
apt install -y wget curl libjansson termux-api nano jq

echo "[*] Start Installing and Setting Up the Verus Miner..."

BASE_DIR="${IRIS_BASE_DIR:-$HOME/ccminerd}"
LOG_DIR="$BASE_DIR/log"
CONFIG_FILE_NAME="${1:-config.json}"
USER_STRING="${2:-${IRIS_USER:-}}"

if [ -z "$USER_STRING" ]; then
  DEVICE_ID=""
  for candidate in "$(getprop ro.serialno 2>/dev/null)" "$(hostname 2>/dev/null)" "$(getprop ro.product.model 2>/dev/null)"; do
    if [ -n "$candidate" ]; then
      DEVICE_ID="$(printf '%s' "$candidate" | tr -cd 'A-Za-z0-9')"
      if [ -n "$DEVICE_ID" ]; then
        break
      fi
    fi
  done

  if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID="$(date +%s | tail -c 6)"
  fi

  USER_STRING="${IRIS_WALLET:-YOUR_WALLET}.iVim-$DEVICE_ID"
fi

REPO_BASE="${IRIS_REPO_BASE:-https://raw.githubusercontent.com/bozzbet/vimgo/main}"
CONFIG_URL="$REPO_BASE/config.json"
VIMGO_URL="$REPO_BASE/vimgo.sh"
VIMSTOP_URL="$REPO_BASE/vimstop.sh"
CCMINER_URL="${IRIS_CCMINER_URL:-https://raw.githubusercontent.com/Darktron/pre-compiled/a73-a53/ccminer}"

echo "[*] Creating ccminerd directory..."
mkdir -p "$BASE_DIR"

echo "[*] Creating log directory..."
mkdir -p "$LOG_DIR"

cd "$BASE_DIR"

echo "[*] Downloading $CONFIG_FILE_NAME..."
curl -fL -o "$CONFIG_FILE_NAME" "$CONFIG_URL"

if [ -n "$USER_STRING" ]; then
  sed -i -E "s#\"user\": \".*\"#\"user\": \"$USER_STRING\"#" "$CONFIG_FILE_NAME"
  echo "[i] Updated user field to: $USER_STRING"
fi

echo "[*] Downloading vimgo.sh..."
curl -fL -o vimgo.sh "$VIMGO_URL"

echo "[*] Downloading vimstop.sh..."
curl -fL -o vimstop.sh "$VIMSTOP_URL"

echo "[*] Downloading ccminer..."
wget -O ccminer "$CCMINER_URL"

echo "[*] Setting executable permissions..."
chmod +x ccminer vimgo.sh vimstop.sh

echo "[✓] Installation complete!"
echo "[i] Config file saved as: $CONFIG_FILE_NAME"
