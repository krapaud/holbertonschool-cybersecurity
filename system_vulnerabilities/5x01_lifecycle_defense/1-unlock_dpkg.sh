#!/bin/bash

# Je retire uniquement les verrous orphelins après vérification des processus.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi

if ! command -v fuser >/dev/null 2>&1; then
    printf '[ERROR] fuser est requis pour vérifier les verrous actifs.\n' >&2
    exit 1
fi
if ! command -v pgrep >/dev/null 2>&1; then
    printf '[ERROR] pgrep est requis pour vérifier les opérations actives.\n' >&2
    exit 1
fi

# Je vérifie qu'aucun gestionnaire de paquets n'est encore en cours.
check_package_processes()
{
    local process_name
    local found_process=0

    for process_name in apt apt-get dpkg dpkg-deb unattended-upgrade \
        packagekitd; do
        if pgrep -x "$process_name" >/dev/null 2>&1; then
            printf '  Active: %s\n' "$process_name"
            found_process=1
        fi
    done

    return "$found_process"
}

printf '=== DPKG Unlock Procedure ===\n\n'
printf 'Checking for active package operations...\n'
active_processes=$(ps -eo pid=,comm= | awk '
    $2 ~ /^(apt|apt-get|dpkg|dpkg-deb|unattended-upgrade|packagekitd)$/ {
        print $1 " " $2
    }
')
if [ -n "$active_processes" ] || ! check_package_processes; then
    if [ -n "$active_processes" ]; then
        printf '%s\n' "$active_processes" | sed 's/^/  Active: /'
    fi
    printf '[ERROR] Une opération APT/DPKG est en cours. Aucun verrou supprimé.\n' >&2
    exit 1
fi
printf '  apt processes: None\n  dpkg processes: None\n\n'

lock_files=(
    /var/lib/dpkg/lock-frontend
    /var/lib/dpkg/lock
    /var/lib/apt/lists/lock
    /var/cache/apt/archives/lock
)
printf 'Removing stale lock files...\n'
for lock_file in "${lock_files[@]}"; do
    [ -e "$lock_file" ] || continue
    if fuser -s "$lock_file"; then
        printf '[ERROR] %s est encore utilisé. Aucun verrou supprimé.\n' \
            "$lock_file" >&2
        exit 1
    fi
done

for lock_file in "${lock_files[@]}"; do
    [ -e "$lock_file" ] || continue
    if rm -f -- "$lock_file"; then
        printf '  %s: Removed\n' "$lock_file"
    else
        printf '[ERROR] Impossible de supprimer %s.\n' "$lock_file" >&2
        exit 1
    fi
done

printf '\nVerification:\n'
active_processes=$(ps -eo pid=,comm= | awk '
    $2 ~ /^(apt|apt-get|dpkg|dpkg-deb|unattended-upgrade|packagekitd)$/ {
        print $1 " " $2
    }
')
if [ -n "$active_processes" ] || ! check_package_processes; then
    if [ -n "$active_processes" ]; then
        printf '%s\n' "$active_processes" | sed 's/^/  Active: /'
    fi
    printf '[ERROR] Un processus de gestion de paquets a démarré pendant le contrôle.\n' >&2
    exit 1
fi
for lock_file in "${lock_files[@]}"; do
    if [ -e "$lock_file" ] && fuser -s "$lock_file"; then
        printf '[ERROR] Verrou actif détecté: %s\n' "$lock_file" >&2
        exit 1
    fi
done
printf '  Package operations: UNLOCKED\n\n'
printf 'DPKG unlocked successfully.\n'
