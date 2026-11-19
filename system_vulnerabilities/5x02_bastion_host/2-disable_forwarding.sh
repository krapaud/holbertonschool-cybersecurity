#!/bin/bash
# Je désactive le routage IPv4 et IPv6 maintenant et après redémarrage.

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
ipv4_parameter=net.ipv4.ip_forward
ipv6_parameter=net.ipv6.conf.all.forwarding

ipv4_current=$(sysctl -n "$ipv4_parameter" 2>/dev/null) || {
    printf '[ERROR] Impossible de lire %s.\n' "$ipv4_parameter" >&2
    exit 1
}
ipv6_current=$(sysctl -n "$ipv6_parameter" 2>/dev/null) || {
    printf '[ERROR] Impossible de lire %s.\n' "$ipv6_parameter" >&2
    exit 1
}

printf '=== Disabling IP Forwarding ===\n\n'
printf 'Current state:\n'
printf '  %s = %s\n' "$ipv4_parameter" "$ipv4_current"
printf '  %s = %s\n' "$ipv6_parameter" "$ipv6_current"

timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
if [ -e "$config_file" ]; then
    if ! mkdir -p "$backup_directory" ||
        ! cp -a -- "$config_file" \
            "$backup_directory/99-hardening.conf.$timestamp"; then
        printf '[ERROR] Impossible de sauvegarder %s.\n' "$config_file" >&2
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
        !/^[[:space:]]*net\.ipv4\.ip_forward[[:space:]]*=/ &&
        !/^[[:space:]]*net\.ipv6\.conf\.all\.forwarding[[:space:]]*=/ {
            print
        }
    ' "$config_file" > "$temporary_file" || {
        printf '[ERROR] Impossible de lire %s.\n' "$config_file" >&2
        exit 1
    }
fi

cat >> "$temporary_file" <<'EOF'
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
EOF

if ! install -o root -g root -m 0644 "$temporary_file" "$config_file"; then
    printf '[ERROR] Impossible d’écrire %s.\n' "$config_file" >&2
    exit 1
fi

printf '\nApplying changes...\n'
if ! sysctl -w "$ipv4_parameter=0" "$ipv6_parameter=0"; then
    printf '[ERROR] Application immédiate des paramètres échouée.\n' >&2
    exit 1
fi

if ! sysctl -p "$config_file" >/dev/null; then
    printf '[ERROR] Chargement de la configuration persistante échoué.\n' >&2
    exit 1
fi

ipv4_verified=$(sysctl -n "$ipv4_parameter" 2>/dev/null) || exit 1
ipv6_verified=$(sysctl -n "$ipv6_parameter" 2>/dev/null) || exit 1

printf '  %s = %s\n' "$ipv4_parameter" "$ipv4_verified"
printf '  %s = %s\n' "$ipv6_parameter" "$ipv6_verified"
printf '\nMaking persistent in %s...\n' "$config_file"
printf '\nVerification:\n'

if [ "$ipv4_verified" != 0 ] || [ "$ipv6_verified" != 0 ]; then
    printf '[ERROR] Le forwarding est encore actif.\n' >&2
    exit 1
fi

printf '  IPv4 forwarding: DISABLED\n'
printf '  IPv6 forwarding: DISABLED\n'
