#!/bin/bash
# J’active les SYN cookies pour limiter les effets des SYN floods.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo dans la VM de laboratoire.\n' >&2
    exit 1
fi

for command_name in sysctl install mktemp; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise introuvable: %s\n' "$command_name" >&2
        exit 1
    fi
done

config_file=/etc/sysctl.d/99-hardening.conf
backup_directory=/var/backups/hardening
parameter=net.ipv4.tcp_syncookies

current_value=$(sysctl -n "$parameter" 2>/dev/null) || {
    printf '[ERROR] Impossible de lire %s.\n' "$parameter" >&2
    exit 1
}

printf '=== Enabling SYN Cookies ===\n\n'
printf 'Current state:\n'
printf '  %s = %s\n' "$parameter" "$current_value"
printf '\nEnabling SYN cookies...\n'

timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
if [ -e "$config_file" ]; then
    if ! mkdir -p "$backup_directory" ||
        ! cp -a -- "$config_file" \
            "$backup_directory/99-hardening.conf.$timestamp"; then
        printf '[ERROR] Sauvegarde de %s impossible.\n' "$config_file" >&2
        exit 1
    fi
fi

temporary_file=$(mktemp) || {
    printf '[ERROR] Impossible de créer un fichier temporaire.\n' >&2
    exit 1
}
trap 'rm -f -- "$temporary_file"' EXIT

if [ -f "$config_file" ]; then
    awk '
        !/^[[:space:]]*net\.ipv4\.tcp_syncookies[[:space:]]*=/ {
            print
        }
    ' "$config_file" > "$temporary_file" || {
        printf '[ERROR] Impossible de lire %s.\n' "$config_file" >&2
        exit 1
    }
fi

printf '%s = 1\n' "$parameter" >> "$temporary_file"

if ! install -o root -g root -m 0644 "$temporary_file" "$config_file"; then
    printf '[ERROR] Impossible d’écrire %s.\n' "$config_file" >&2
    exit 1
fi

if ! sysctl -w "$parameter=1" >/dev/null; then
    printf '[ERROR] Activation immédiate des SYN cookies échouée.\n' >&2
    exit 1
fi

if ! sysctl -p "$config_file" >/dev/null; then
    printf '[ERROR] Chargement de la configuration persistante échoué.\n' >&2
    exit 1
fi

verified_value=$(sysctl -n "$parameter" 2>/dev/null) || {
    printf '[ERROR] Impossible de vérifier %s.\n' "$parameter" >&2
    exit 1
}
if [ "$verified_value" != 1 ]; then
    printf '[ERROR] %s vaut encore %s.\n' "$parameter" "$verified_value" >&2
    exit 1
fi

printf '  %s = %s\n' "$parameter" "$verified_value"
printf '\nConfiguration saved to %s\n' "$config_file"
printf '\nSYN flood protection: ENABLED\n'
