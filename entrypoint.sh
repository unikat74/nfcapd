#!/bin/sh
set -eu

FLOW_DIR="${FLOW_DIR:-/flows}"
PORT="${PORT:-12345}"
SUBDIR_FORMAT="${SUBDIR_FORMAT:-1}"
ROTATE_INTERVAL="${ROTATE_INTERVAL:-300}"

mkdir -p "$FLOW_DIR"

exec nfcapd \
  -w "$FLOW_DIR" \
  -p "$PORT" \
  -S "$SUBDIR_FORMAT" \
  -t "$ROTATE_INTERVAL" \
  -z
