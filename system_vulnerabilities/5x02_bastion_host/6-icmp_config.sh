#!/bin/bash
# Je bloque les pings broadcast, mais garde le ping direct pour le diagnostic.

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
icmp_settings=(
    net.ipv4.icmp_echo_ignore_broadcasts=1
    net.ipv4.icmp_echo_ignore_all=0
    net.ipv4.icmp_ignore_bogus_error_responses=1
)

printf '=== ICMP Configuration ===\n\n'
printf 'Disabling broadcast ping response (Smurf prevention)...\n'
printf '  net.ipv4.icmp_echo_ignore_broadcasts = 1\n\n'
printf 'Keeping unicast ping enabled for diagnostics.\n'
printf '  net.ipv4.icmp_echo_ignore_all = 0\n\n'
printf 'Ignoring bogus ICMP error responses...\n'
printf '  net.ipv4.icmp_ignore_bogus_error_responses = 1\n'

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
        !/^[[:space:]]*net\.ipv4\.icmp_echo_ignore_broadcasts[[:space:]]*=/ &&
        !/^[[:space:]]*net\.ipv4\.icmp_echo_ignore_all[[:space:]]*=/ &&
        !/^[[:space:]]*net\.ipv4\.icmp_ignore_bogus_error_responses[[:space:]]*=/ {
            print
        }
    ' "$config_file" > "$temporary_file" || {
        printf '[ERROR] Impossible de lire %s.\n' "$config_file" >&2
        exit 1
    }
fi

for setting in "${icmp_settings[@]}"; do
    printf 'net.%s\n' "${setting#net.}" >> "$temporary_file"
done

if ! install -o root -g root -m 0644 "$temporary_file" "$config_file"; then
    printf '[ERROR] Impossible d’écrire %s.\n' "$config_file" >&2
    exit 1
fi

if ! sysctl -w "${icmp_settings[@]}" >/dev/null; then
    printf '[ERROR] Application immédiate des paramètres ICMP échouée.\n' >&2
    exit 1
fi

if ! sysctl -p "$config_file" >/dev/null; then
    printf '[ERROR] Chargement de la configuration persistante échoué.\n' >&2
    exit 1
fi

for setting in "${icmp_settings[@]}"; do
    parameter=${setting%%=*}
    expected_value=${setting##*=}
    actual_value=$(sysctl -n "$parameter" 2>/dev/null) || {
        printf '[ERROR] Impossible de vérifier %s.\n' "$parameter" >&2
        exit 1
    }
    if [ "$actual_value" != "$expected_value" ]; then
        printf '[ERROR] %s vaut %s au lieu de %s.\n' \
            "$parameter" "$actual_value" "$expected_value" >&2
        exit 1
    fi
done

printf '\nConfiguration saved to %s\n' "$config_file"
printf '\nBroadcast ping: DISABLED\n'
printf 'Unicast ping: ENABLED\n'
