#!/bin/bash

# Je valide la configuration avant de relancer Apache et son contrôle HTTP.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi
if ! command -v apache2ctl >/dev/null 2>&1 ||
    ! command -v systemctl >/dev/null 2>&1 ||
    ! command -v curl >/dev/null 2>&1 || ! command -v awk >/dev/null 2>&1 ||
    ! command -v date >/dev/null 2>&1; then
    printf '[ERROR] Une commande requise est introuvable.\n' >&2
    exit 1
fi

printf '=== Apache Recovery ===\n'
printf 'Configuration test...\n'
if ! apache2ctl -t; then
    printf '[ERROR] La configuration Apache est invalide.\n' >&2
    exit 1
fi
printf 'Syntax: OK\n'
printf 'Modules loaded: '
apache2ctl -M 2>/dev/null | awk '
    /_module/ {
        gsub(/_module/, "", $1)
        if (count++) printf ", "
        printf "%s", $1
    }
    END { print "" }
'
printf 'Starting Apache service...\n'
if ! systemctl start apache2; then
    printf '[ERROR] Apache n’a pas démarré.\n' >&2
    systemctl status apache2 --no-pager >&2 || true
    exit 1
fi
if ! systemctl is-active --quiet apache2; then
    printf '[ERROR] Apache n’est pas actif après son démarrage.\n' >&2
    systemctl status apache2 --no-pager >&2 || true
    exit 1
fi
printf '  apache2.service: Started\n'
printf 'Health check...\n'
health_result=$(curl --connect-timeout 5 --max-time 10 -sS -o /dev/null \
    -w '%{http_code} %{time_total}' http://127.0.0.1/) || {
    printf '[ERROR] La requête HTTP vers Apache a échoué.\n' >&2
    exit 1
}
read -r http_status response_seconds <<< "$health_result"
if [ "$http_status" != 200 ]; then
    printf '[ERROR] Le contrôle HTTP a retourné %s.\n' "$http_status" >&2
    exit 1
fi
response_milliseconds=$(awk -v seconds="$response_seconds" \
    'BEGIN { printf "%.0f", seconds * 1000 }')
printf 'HTTP GET /: %s OK\n' "$http_status"
printf 'Response time: %sms\n' "$response_milliseconds"
printf 'Apache restored successfully.\n'
active_since=$(systemctl show -p ActiveEnterTimestamp --value apache2)
if [ -n "$active_since" ]; then
    active_epoch=$(date -d "$active_since" '+%s' 2>/dev/null || true)
    if [[ "$active_epoch" =~ ^[0-9]+$ ]]; then
        uptime_minutes=$((( $(date '+%s') - active_epoch ) / 60))
        printf 'Service uptime: %s days, %s hours, %s minutes\n' \
            "$((uptime_minutes / 1440))" \
            "$(((uptime_minutes % 1440) / 60))" \
            "$((uptime_minutes % 60))"
    fi
fi
