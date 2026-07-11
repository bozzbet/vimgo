#!/data/data/com.termux/files/usr/bin/bash

set -e

export PREFIX=/data/data/com.termux/files/usr
export HOME=/data/data/com.termux/files/home
export PATH=$PREFIX/bin:$PATH

CCMINER_DIR="${IRIS_BASE_DIR:-$HOME/ccminerd}"

exec "$CCMINER_DIR/vimgo.sh" "$@"
