#!/bin/bash

# Je limite les origines automatiques aux dépôts de sécurité Ubuntu.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi
if [ ! -r /etc/os-release ]; then
    printf '[ERROR] Impossible de lire /etc/os-release.\n' >&2
    exit 1
fi
release=$(awk -F= '$1 == "VERSION_CODENAME" { gsub(/"/, "", $2); print $2 }' \
    /etc/os-release)
distribution=$(awk -F= '$1 == "ID" { gsub(/"/, "", $2); print $2 }' \
    /etc/os-release)
if [ -z "$release" ] || [ -z "$distribution" ]; then
    printf '[ERROR] Nom de version Ubuntu introuvable.\n' >&2
    exit 1
fi

config_file=/etc/apt/apt.conf.d/50unattended-upgrades
backup_directory=/var/backups/lifecycle-defense
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
mkdir -p "$backup_directory" || exit 1
if [ -f "$config_file" ]; then
    cp -a -- "$config_file" "$backup_directory/50unattended-upgrades.$timestamp" || {
        printf '[ERROR] Sauvegarde de la configuration impossible.\n' >&2
        exit 1
    }
fi
temporary_file=$(mktemp) || exit 1
trap 'rm -f -- "$temporary_file"' EXIT
cat > "$temporary_file" <<EOF
Unattended-Upgrade::Allowed-Origins {
    "$distribution:$release-security";
};
EOF
if ! grep -q "${release}-security" "$temporary_file"; then
    printf '[ERROR] Origine sécurité absente du fichier préparé.\n' >&2
    exit 1
fi
install -o root -g root -m 0644 "$temporary_file" "$config_file" || {
    printf '[ERROR] Écriture de la configuration échouée.\n' >&2
    exit 1
}
printf 'Allowed unattended-upgrade origin: %s:%s-security\n' \
    "$distribution" "$release"
printf 'Configuration: %s\n' "$config_file"
