#!/bin/bash

# Je cherche les installations proches de l’heure d’incident dans APT/DPKG.

set -o pipefail

if [ "$#" -ne 1 ]; then
    printf 'Usage: %s "YYYY-MM-DD HH:MM"\n' "${0##*/}" >&2
    exit 2
fi
incident_time=$(date -d "$1" '+%s' 2>/dev/null) || {
    printf '[ERROR] Date invalide. Format attendu: YYYY-MM-DD HH:MM\n' >&2
    exit 2
}

printf '=== Update Incident Review ===\n'
printf 'Incident time: %s\n\n' "$1"
for log_file in /var/log/apt/history.log /var/log/dpkg.log; do
    [ -r "$log_file" ] || continue
    while IFS= read -r log_line; do
        log_date=${log_line:0:19}
        log_epoch=$(date -d "$log_date" '+%s' 2>/dev/null) || continue
        if [ "$log_epoch" -le "$incident_time" ] &&
            [ $((incident_time - log_epoch)) -le 86400 ]; then
            printf '%s | %s | %s\n' "$log_date" \
                "$log_file" "${log_line:20}"
        fi
    done < "$log_file"
done | sort -k1,2

printf '\nReview the closest package operation, then compare its time and '
printf 'package list with the first service error.\n'
