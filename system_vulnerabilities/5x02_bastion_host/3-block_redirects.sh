#!/bin/bash
# Je bloque les redirections ICMP IPv4 et IPv6, en réception et en émission.

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
redirect_parameters=(
    net.ipv4.conf.all.accept_redirects
    net.ipv4.conf.default.accept_redirects
    net.ipv6.conf.all.accept_redirects
    net.ipv6.conf.default.accept_redirects
    net.ipv4.conf.all.send_redirects
    net.ipv4.conf.default.send_redirects
)

printf '=== Blocking ICMP Redirects ===\n\n'
printf 'Disabling redirect acceptance...\n'
printf '  %s = 0\n' "${redirect_parameters[@]:0:4}"
printf '\nDisabling redirect sending...\n'
printf '  %s = 0\n' "${redirect_parameters[@]:4:2}"

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
        !/^[[:space:]]*net\.ipv4\.conf\.(all|default)\.accept_redirects[[:space:]]*=/ &&
        !/^[[:space:]]*net\.ipv6\.conf\.(all|default)\.accept_redirects[[:space:]]*=/ &&
        !/^[[:space:]]*net\.ipv4\.conf\.(all|default)\.send_redirects[[:space:]]*=/ {
            print
        }
    ' "$config_file" > "$temporary_file" || {
        printf '[ERROR] Impossible de lire %s.\n' "$config_file" >&2
        exit 1
    }
fi

for parameter in "${redirect_parameters[@]}"; do
    printf '%s = 0\n' "$parameter" >> "$temporary_file"
done

if ! install -o root -g root -m 0644 "$temporary_file" "$config_file"; then
    printf '[ERROR] Impossible d’écrire %s.\n' "$config_file" >&2
    exit 1
fi

if ! sysctl -w \
    net.ipv4.conf.all.accept_redirects=0 \
    net.ipv4.conf.default.accept_redirects=0 \
    net.ipv6.conf.all.accept_redirects=0 \
    net.ipv6.conf.default.accept_redirects=0 \
    net.ipv4.conf.all.send_redirects=0 \
    net.ipv4.conf.default.send_redirects=0 >/dev/null; then
    printf '[ERROR] Application immédiate des paramètres échouée.\n' >&2
    exit 1
fi

if ! sysctl -p "$config_file" >/dev/null; then
    printf '[ERROR] Chargement de la configuration persistante échoué.\n' >&2
    exit 1
fi

for parameter in "${redirect_parameters[@]}"; do
    value=$(sysctl -n "$parameter" 2>/dev/null) || {
        printf '[ERROR] Impossible de vérifier %s.\n' "$parameter" >&2
        exit 1
    }
    if [ "$value" != 0 ]; then
        printf '[ERROR] %s vaut encore %s.\n' "$parameter" "$value" >&2
        exit 1
    fi
done

printf '\nConfiguration saved to %s\n' "$config_file"
printf '\nICMP redirects: BLOCKED\n'
