#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BIN_DIR="${HOME}/.local/bin"

mkdir -p "$BIN_DIR"
cd "$ROOT_DIR"

swift build -c release
install -m 755 ".build/release/kuma" "$BIN_DIR/kuma"
ln -sf "$BIN_DIR/kuma" "$BIN_DIR/ku"

printf 'Installed kuma at %s/kuma\n' "$BIN_DIR"
printf 'Installed ku alias at %s/ku\n' "$BIN_DIR"
