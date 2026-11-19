#!/bin/bash
# Je refuse les paquets qui imposent leur propre itinéraire réseau.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] %s %s.\n' \
        'Exécute ce script avec sudo' 'dans la VM de laboratoire' >&2
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
source_route_settings=(
    net.ipv4.conf.all.accept_source_route=0
    net.ipv4.conf.default.accept_source_route=0
    net.ipv6.conf.all.accept_source_route=0
    net.ipv6.conf.default.accept_source_route=0
)

printf '=== Blocking Source Routing ===\n\n'
printf 'Disabling source route acceptance...\n'

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
        {
            key = "^[[:space:]]*net\\.ipv[46]\\.conf\\."
            key = key "(all|default)\\.accept_source_route"
            key = key "[[:space:]]*="
        }
        $0 !~ key {
            print
        }
    ' "$config_file" > "$temporary_file" || {
        printf '[ERROR] Impossible de lire %s.\n' "$config_file" >&2
        exit 1
    }
fi

for setting in "${source_route_settings[@]}"; do
    printf '%s\n' "$setting" >> "$temporary_file"
done

if ! install -o root -g root -m 0644 "$temporary_file" "$config_file"; then
    printf '[ERROR] Impossible d’écrire %s.\n' "$config_file" >&2
    exit 1
fi

if ! sysctl -w "${source_route_settings[@]}" >/dev/null; then
    printf '[ERROR] %s.\n' \
        'Désactivation immédiate du source routing échouée' >&2
    exit 1
fi

if ! sysctl -p "$config_file" >/dev/null; then
    printf '[ERROR] Chargement de la configuration persistante échoué.\n' >&2
    exit 1
fi

for setting in "${source_route_settings[@]}"; do
    parameter=${setting%%=*}
    value=$(sysctl -n "$parameter" 2>/dev/null) || {
        printf '[ERROR] Impossible de vérifier %s.\n' "$parameter" >&2
        exit 1
    }
    if [ "$value" != 0 ]; then
        printf '[ERROR] %s vaut encore %s.\n' "$parameter" "$value" >&2
        exit 1
    fi
    printf '  %s = %s\n' "$parameter" "$value"
done

printf '\nConfiguration saved to %s\n' "$config_file"
printf '\nSource-routed packets: BLOCKED\n'
