#!/bin/bash

# Je demande un redémarrage automatique seulement après mise à jour du noyau.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi

config_file=/etc/apt/apt.conf.d/52lifecycle-reboot
backup_directory=/var/backups/lifecycle-defense
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
mkdir -p "$backup_directory" || exit 1
if [ -f "$config_file" ]; then
    cp -a -- "$config_file" "$backup_directory/52lifecycle-reboot.$timestamp" || {
        printf '[ERROR] Sauvegarde de la politique impossible.\n' >&2
        exit 1
    }
fi
temporary_file=$(mktemp) || exit 1
trap 'rm -f -- "$temporary_file"' EXIT
cat > "$temporary_file" <<'EOF'
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
Unattended-Upgrade::Automatic-Reboot-Time "04:30";
EOF
install -o root -g root -m 0644 "$temporary_file" "$config_file" || {
    printf '[ERROR] Écriture de la politique de redémarrage échouée.\n' >&2
    exit 1
}
printf 'Automatic reboot: enabled when required by package updates\n'
printf 'Scheduled reboot time: 04:30, only when no user is logged in\n'
printf 'Configuration: %s\n' "$config_file"
