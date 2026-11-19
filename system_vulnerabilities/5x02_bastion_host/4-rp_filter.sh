#!/bin/bash
# J’active le filtrage strict des adresses source usurpées.

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
filter_parameters=(
    net.ipv4.conf.all.rp_filter
    net.ipv4.conf.default.rp_filter
)

printf '=== Enabling Reverse Path Filtering ===\n\n'
printf 'Setting strict mode (1) for all interfaces...\n'

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
        !/^[[:space:]]*net\.ipv4\.conf\.(all|default)\.rp_filter[[:space:]]*=/ {
            print
        }
    ' "$config_file" > "$temporary_file" || {
        printf '[ERROR] Impossible de lire %s.\n' "$config_file" >&2
        exit 1
    }
fi

for parameter in "${filter_parameters[@]}"; do
    printf '%s = 1\n' "$parameter" >> "$temporary_file"
done

if ! install -o root -g root -m 0644 "$temporary_file" "$config_file"; then
    printf '[ERROR] Impossible d’écrire %s.\n' "$config_file" >&2
    exit 1
fi

if ! sysctl -w \
    net.ipv4.conf.all.rp_filter=1 \
    net.ipv4.conf.default.rp_filter=1 >/dev/null; then
    printf '[ERROR] Activation immédiate de rp_filter échouée.\n' >&2
    exit 1
fi

if ! sysctl -p "$config_file" >/dev/null; then
    printf '[ERROR] Chargement de la configuration persistante échoué.\n' >&2
    exit 1
fi

for parameter in "${filter_parameters[@]}"; do
    value=$(sysctl -n "$parameter" 2>/dev/null) || {
        printf '[ERROR] Impossible de vérifier %s.\n' "$parameter" >&2
        exit 1
    }
    if [ "$value" != 1 ]; then
        printf '[ERROR] %s vaut encore %s.\n' "$parameter" "$value" >&2
        exit 1
    fi
    printf '  %s = %s\n' "$parameter" "$value"
done

printf '\nConfiguration saved to %s\n' "$config_file"
printf '\nReverse path filtering: STRICT MODE\n'
printf 'Spoofed packets will be dropped.\n'
