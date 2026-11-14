#!/bin/bash

# Je bloque les mises à jour automatiques d’un paquet avec une justification.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi
if [ "$#" -ne 2 ]; then
    printf 'Usage: %s package "reason"\n' "${0##*/}" >&2
    exit 2
fi
package=$1
reason=$2
if [[ ! "$package" =~ ^[a-zA-Z0-9][a-zA-Z0-9.+:-]*$ ]] ||
    [[ ! "$reason" =~ [a-zA-Z0-9] ]]; then
    printf '[ERROR] Paquet ou justification invalide.\n' >&2
    exit 2
fi
command -v apt-mark >/dev/null 2>&1 || {
    printf '[ERROR] apt-mark est introuvable.\n' >&2
    exit 1
}
apt-mark hold "$package" || exit 1
log_file=/var/log/lifecycle-defense.log
printf '%s HOLD %s reason=%q\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$package" "$reason" \
    >> "$log_file" || {
    apt-mark unhold "$package" >/dev/null 2>&1 || true
    printf '[ERROR] Journalisation échouée, tentative de retour arrière faite.\n' >&2
    exit 1
}
printf 'Package held: %s\nReason: %s\n' "$package" "$reason"
