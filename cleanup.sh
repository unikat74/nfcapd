#!/bin/sh
set -eu

FLOW_DIR="${FLOW_DIR:-/flows}"
SLEEP_SECONDS="${SLEEP_SECONDS:-3600}"

mkdir -p "$FLOW_DIR"

while true; do
  CUTOFF="$(date -d '13 months ago' '+%Y-%m-%d %H:%M:%S')"

  find "$FLOW_DIR" \
    -type f \
    -name 'nfcapd.*' \
    ! -newermt "$CUTOFF" \
    -delete

  find "$FLOW_DIR" \
    -mindepth 1 \
    -depth \
    -type d \
    -empty \
    -delete || true

  sleep "$SLEEP_SECONDS"
done
