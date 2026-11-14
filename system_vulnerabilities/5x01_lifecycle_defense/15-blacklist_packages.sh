#!/bin/bash

# Je protège Apache et MySQL des mises à jour automatiques non validées.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi

config_file=/etc/apt/apt.conf.d/51lifecycle-blacklist
backup_directory=/var/backups/lifecycle-defense
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
mkdir -p "$backup_directory" || exit 1
if [ -f "$config_file" ]; then
    cp -a -- "$config_file" "$backup_directory/51lifecycle-blacklist.$timestamp" || {
        printf '[ERROR] Sauvegarde de la liste d’exclusion impossible.\n' >&2
        exit 1
    }
fi
temporary_file=$(mktemp) || exit 1
trap 'rm -f -- "$temporary_file"' EXIT
cat > "$temporary_file" <<'EOF'
Unattended-Upgrade::Package-Blacklist {
    "^apache2$";
    "^mysql-server$";
    "^mysql-client$";
    "^mysql-community-server$";
};
EOF
install -o root -g root -m 0644 "$temporary_file" "$config_file" || {
    printf '[ERROR] Écriture de la liste d’exclusion échouée.\n' >&2
    exit 1
}
printf 'Protected packages from unattended upgrades: apache2, mysql-server\n'
printf 'Configuration: %s\n' "$config_file"
