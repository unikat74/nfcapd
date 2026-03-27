#!/bin/sh
set -eu

FLOW_DIR="${FLOW_DIR:-/flows}"
NTFY_URL="${NTFY_URL:-}"
FILE_AGE_THRESHOLD="${FILE_AGE_THRESHOLD:-15}"
DISK_THRESHOLD="${DISK_THRESHOLD:-90}"
CHECK_INTERVAL="${CHECK_INTERVAL:-300}"
HOSTNAME_LABEL="${HOSTNAME_LABEL:-$(hostname)}"

STATE_DIR="/tmp/monitor_state"
STATE_FILES_ALERT="${STATE_DIR}/files_alert_active"
STATE_DISK_ALERT="${STATE_DIR}/disk_alert_active"
STATE_GRACE="${STATE_DIR}/startup_grace_done"

if [ -z "$NTFY_URL" ]; then
    printf '%s [monitor] NTFY_URL nie jest ustawiony — skonfiguruj NTFY_URL i uruchom kontener ponownie\n' \
        "$(date '+%Y-%m-%dT%H:%M:%S')"
    exit 1
fi

mkdir -p "$STATE_DIR"

log() {
    printf '%s [monitor] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*"
}

notify() {
    title="$1"
    message="$2"
    priority="${3:-default}"
    tags="${4:-white_check_mark}"

    log "NOTIFY: ${title}: ${message}"

    if [ -z "$NTFY_URL" ]; then
        return 0
    fi

    curl \
        --silent \
        --max-time 10 \
        --retry 2 \
        --retry-delay 3 \
        -H "Title: ${title}" \
        -H "Priority: ${priority}" \
        -H "Tags: ${tags}" \
        -d "${message}" \
        "$NTFY_URL" || true
}

check_files() {
    # Sprawdź grace period — nie alertuj zanim pojawi się pierwszy plik
    if [ ! -f "$STATE_GRACE" ]; then
        any=$(find "$FLOW_DIR" -type f -name 'nfcapd.[0-9]*' 2>/dev/null | head -n 1)
        if [ -z "$any" ]; then
            log "Grace period: brak plikow nfcapd.* w ${FLOW_DIR}, pomijam sprawdzenie"
            return 0
        fi
        touch "$STATE_GRACE"
    fi

    # Szukaj pliku swiezszego niz FILE_AGE_THRESHOLD minut
    fresh=$(find "$FLOW_DIR" \
        -type f \
        -name 'nfcapd.[0-9]*' \
        -mmin "-${FILE_AGE_THRESHOLD}" \
        2>/dev/null | head -n 1)

    if [ -n "$fresh" ]; then
        log "FILES OK — swiezy plik: ${fresh}"
        if [ -f "$STATE_FILES_ALERT" ]; then
            notify \
                "RECOVERY: Pliki NetFlow OK — ${HOSTNAME_LABEL}" \
                "nfcapd znow generuje pliki. Ostatni swiezy plik: ${fresh}" \
                "default" \
                "white_check_mark,arrow_up"
            rm -f "$STATE_FILES_ALERT"
        fi
    else
        if [ ! -f "$STATE_FILES_ALERT" ]; then
            log "FILES ALERT — brak pliku nfcapd.* mlodszego niz ${FILE_AGE_THRESHOLD} minut"
            notify \
                "ALERT: Brak plikow NetFlow — ${HOSTNAME_LABEL}" \
                "Zadnego pliku nfcapd nie utworzono przez ostatnie ${FILE_AGE_THRESHOLD} minut. Sprawdz czy kontener nfcapd dziala i czy urzadzenia wysylaja dane." \
                "urgent" \
                "rotating_light,arrow_down"
            touch "$STATE_FILES_ALERT"
        else
            log "FILES ALERT nadal aktywny (brak swiezego pliku, powiadomienie juz wyslane)"
        fi
    fi
}

check_disk() {
    used_pct=$(df -P "$FLOW_DIR" 2>/dev/null \
        | awk 'NR==2 {gsub(/%/, ""); print $5}')

    if [ -z "$used_pct" ]; then
        log "DISK WARNING — nie mozna odczytac zajętosci dysku dla ${FLOW_DIR}"
        return 0
    fi

    log "DISK ${used_pct}% zajety (prog: ${DISK_THRESHOLD}%)"

    if [ "$used_pct" -ge "$DISK_THRESHOLD" ]; then
        if [ ! -f "$STATE_DISK_ALERT" ]; then
            log "DISK ALERT — ${used_pct}% >= ${DISK_THRESHOLD}%"
            notify \
                "ALERT: Malo miejsca na dysku — ${HOSTNAME_LABEL}" \
                "Dysk zajety w ${used_pct}% (prog: ${DISK_THRESHOLD}%). Katalog: ${FLOW_DIR}. Rozwaz rozszerzenie przestrzeni lub reczne czyszczenie." \
                "urgent" \
                "rotating_light,floppy_disk"
            touch "$STATE_DISK_ALERT"
        else
            log "DISK ALERT nadal aktywny (${used_pct}% >= ${DISK_THRESHOLD}%)"
        fi
    else
        if [ -f "$STATE_DISK_ALERT" ]; then
            log "DISK OK — recovery (${used_pct}% < ${DISK_THRESHOLD}%)"
            notify \
                "RECOVERY: Miejsce na dysku OK — ${HOSTNAME_LABEL}" \
                "Zajêtosc dysku wrocila do ${used_pct}% (prog: ${DISK_THRESHOLD}%). Katalog: ${FLOW_DIR}." \
                "default" \
                "white_check_mark,floppy_disk"
            rm -f "$STATE_DISK_ALERT"
        fi
    fi
}

log "Start. FLOW_DIR=${FLOW_DIR} FILE_AGE_THRESHOLD=${FILE_AGE_THRESHOLD}m DISK_THRESHOLD=${DISK_THRESHOLD}% CHECK_INTERVAL=${CHECK_INTERVAL}s NTFY_URL=${NTFY_URL:-<nie ustawiony>}"

while true; do
    check_files
    check_disk
    sleep "$CHECK_INTERVAL"
done
