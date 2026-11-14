#!/bin/bash

# J’archive les réglages APT, systemd et le journal de ce projet.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
backup_root=/var/backups/lifecycle-defense
archive="$backup_root/config-$timestamp.tar.gz"
mkdir -p "$backup_root" || exit 1
paths=()
for path in /etc/apt/apt.conf.d /etc/apt/preferences \
    /etc/apt/preferences.d /etc/systemd/system/apt-daily.timer.d \
    /etc/systemd/system/apt-daily-upgrade.timer.d \
    /etc/logrotate.d/lifecycle-defense \
    /var/log/lifecycle-defense.log; do
    [ -e "$path" ] && paths+=("$path")
done
if [ "${#paths[@]}" -eq 0 ]; then
    printf '[ERROR] Aucun réglage de gestion des correctifs à archiver.\n' >&2
    exit 1
fi
tar -czf "$archive" "${paths[@]}" || {
    rm -f -- "$archive"
    printf '[ERROR] Création de l’archive échouée.\n' >&2
    exit 1
}
chmod 0600 "$archive" || exit 1
tar -tzf "$archive" >/dev/null || {
    printf '[ERROR] Vérification de l’archive échouée.\n' >&2
    exit 1
}
checksum_file="$archive.sha256"
if ! sha256sum "$archive" > "$checksum_file"; then
    rm -f -- "$archive" "$checksum_file"
    printf '[ERROR] Calcul de l’empreinte SHA-256 échoué.\n' >&2
    exit 1
fi
chmod 0600 "$checksum_file" || exit 1
printf 'Configuration backup: %s\n' "$archive"
printf 'Archive integrity: verified\n'
printf 'SHA-256 checksum: %s\n' "$checksum_file"
