#!/data/data/com.termux/files/usr/bin/bash

set -e

export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=$PREFIX/bin:$PATH

if ! pgrep -x ccminer >/dev/null 2>&1; then
    termux-wake-unlock 2>/dev/null || true
    echo "ccminer is not running."
    exit 0
fi

pkill -INT -x ccminer

for _ in 1 2 3 4 5; do
    if ! pgrep -x ccminer >/dev/null 2>&1; then
        termux-wake-unlock 2>/dev/null || true
        echo "ccminer stopped."
        exit 0
    fi
    sleep 1
done

pkill -KILL -x ccminer
termux-wake-unlock 2>/dev/null || true
echo "ccminer force stopped."
