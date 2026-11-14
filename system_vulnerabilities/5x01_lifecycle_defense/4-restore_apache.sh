#!/bin/bash

# Je valide la configuration avant de relancer Apache et son contrôle HTTP.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi
if ! command -v apache2ctl >/dev/null 2>&1 ||
    ! command -v systemctl >/dev/null 2>&1 ||
    ! command -v curl >/dev/null 2>&1; then
    printf '[ERROR] apache2ctl, systemctl ou curl est introuvable.\n' >&2
    exit 1
fi

printf '=== Apache Recovery ===\n'
printf 'Configuration test...\n'
if ! apache2ctl configtest; then
    printf '[ERROR] La configuration Apache est invalide.\n' >&2
    exit 1
fi
printf 'Syntax: OK\n'
printf 'Modules loaded: '
apache2ctl -M 2>/dev/null | awk '/_module/ { gsub(/_module/, "", $1); printf "%s ", $1 } END { print "" }'
printf 'Starting Apache service...\n'
if ! systemctl restart apache2; then
    printf '[ERROR] Apache n’a pas redémarré.\n' >&2
    systemctl status apache2 --no-pager >&2 || true
    exit 1
fi
systemctl status apache2 --no-pager | sed -n '1,3p'
printf 'Health check...\n'
http_status=$(curl --connect-timeout 5 --max-time 10 -sS -o /dev/null \
    -w '%{http_code}' http://127.0.0.1/)
if [ "$http_status" != 200 ]; then
    printf '[ERROR] Le contrôle HTTP a retourné %s.\n' "$http_status" >&2
    exit 1
fi
printf 'HTTP GET /: %s OK\n' "$http_status"
printf 'Apache restored successfully.\n'
