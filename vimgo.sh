#!/data/data/com.termux/files/usr/bin/bash

set -e

export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=$PREFIX/bin:$PATH

CCMINER_DIR="${IRIS_BASE_DIR:-$HOME/ccminerd}"
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

    local config_candidate
    config_candidate=$(find "$CCMINER_DIR" -maxdepth 1 -type f \( -name '*.json' -o -name '*.conf' -o -name '*.cfg' \) 2>/dev/null | sort | head -n 1)
    if [ -n "$config_candidate" ]; then
        printf '%s\n' "$config_candidate"
        return 0
    fi

    return 1
}

termux-wake-lock
mkdir -p "$CCMINER_DIR"
cd "$CCMINER_DIR"

CONFIG_FILE="$(resolve_config_file)" || {
    echo "No miner config file found. Expected config.json or another .json/.conf/.cfg file in $CCMINER_DIR." >&2
    exit 1
}

./ccminer -c "$CONFIG_FILE"
