#!/bin/bash

# Je sauvegarde la configuration avant de retirer le service FTP vulnérable.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi
for command_name in apt-get systemctl ss tar; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise absente: %s\n' "$command_name" >&2
        exit 1
    fi
done
if pgrep -x apt >/dev/null || pgrep -x apt-get >/dev/null ||
    pgrep -x dpkg >/dev/null || pgrep -x unattended-upgrade >/dev/null; then
    printf '[ERROR] Une opération de paquets est déjà en cours.\n' >&2
    exit 1
fi

backup_directory=/var/backups/lifecycle-defense
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
mkdir -p "$backup_directory" || {
    printf '[ERROR] Impossible de créer %s.\n' "$backup_directory" >&2
    exit 1
}
config_files=()
for config_file in /etc/vsftpd.conf /etc/vsftpd.user_list; do
    [ ! -e "$config_file" ] || config_files+=("$config_file")
done
if [ "${#config_files[@]}" -gt 0 ]; then
    if ! tar -czf "$backup_directory/vsftpd-$timestamp.tar.gz" \
        "${config_files[@]}"; then
        printf '[ERROR] Sauvegarde de la configuration FTP échouée.\n' >&2
        exit 1
    fi
    chmod 600 "$backup_directory/vsftpd-$timestamp.tar.gz"
    printf 'Configuration backup: %s/vsftpd-%s.tar.gz\n' \
        "$backup_directory" "$timestamp"
fi

printf '=== Vulnerable Service Removal ===\n'
printf 'Target: vsftpd (CVE-2011-2523 - backdoor)\n'
systemctl stop vsftpd 2>/dev/null || true
systemctl disable vsftpd 2>/dev/null || true
if dpkg-query -W -f='${db:Status-Status}' vsftpd 2>/dev/null | grep -q installed; then
    if ! DEBIAN_FRONTEND=noninteractive apt-get purge -y vsftpd; then
        printf '[ERROR] La purge de vsftpd a échoué.\n' >&2
        exit 1
    fi
else
    printf 'Package status: already absent\n'
fi

if dpkg-query -W -f='${db:Status-Status}' vsftpd 2>/dev/null | grep -q installed; then
    printf '[ERROR] vsftpd est encore installé.\n' >&2
    exit 1
fi
if ss -lnt '( sport = :21 )' | grep -q LISTEN; then
    printf '[ERROR] Le port 21 écoute toujours.\n' >&2
    exit 1
fi
printf 'Verification: package not installed; port 21 not listening\n'
printf 'Vulnerability CVE-2011-2523: REMEDIATED\n'
