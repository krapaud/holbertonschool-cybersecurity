#!/bin/bash

# Je sauvegarde chaque fichier avant de corriger les permissions risquées.

set -o pipefail
umask 077

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi

timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
backup_directory=/var/backups/lifecycle-defense/permissions-$timestamp
log_file=/var/log/lifecycle-defense.log
mkdir -p "$backup_directory" || {
    printf '[ERROR] Impossible de créer le dossier de sauvegarde.\n' >&2
    exit 1
}
touch "$log_file" || {
    printf '[ERROR] Impossible d’écrire le journal d’audit.\n' >&2
    exit 1
}
chmod 600 "$log_file"

record_change()
{
    printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" \
        >> "$log_file"
}

backup_path()
{
    local target_path="$1"
    local relative_path
    relative_path=${target_path#/}
    mkdir -p "$backup_directory/${relative_path%/*}" || return 1
    cp -a -- "$target_path" "$backup_directory/$relative_path"
}

printf '=== Permission Remediation ===\n'
if [ -e /usr/local/bin/backup ]; then
    mode=$(stat -c '%a' /usr/local/bin/backup) || exit 1
    if (( (8#$mode) & 04000 )); then
        backup_path /usr/local/bin/backup || exit 1
        chmod u-s /usr/local/bin/backup || exit 1
        record_change "removed SUID from /usr/local/bin/backup; saved mode=$mode"
        printf 'SUID/SGID: /usr/local/bin/backup SUID removed (was %s)\n' "$mode"
    fi
fi

for writable_file in /etc/cron.daily/backup.sh /opt/scripts/cleanup.sh; do
    [ -f "$writable_file" ] || continue
    mode=$(stat -c '%a' "$writable_file") || exit 1
    if (( (8#$mode) & 0002 )); then
        backup_path "$writable_file" || exit 1
        chmod 0755 "$writable_file" || exit 1
        record_change "removed world-write permission from $writable_file; saved mode=$mode"
        printf 'World-writable: %s %s to %s\n' "$writable_file" "$mode" \
            "$(stat -c '%a' "$writable_file")"
    fi
done

if [ -f /var/www/html/config.php ]; then
    backup_path /var/www/html/config.php || exit 1
    chown www-data:www-data /var/www/html/config.php || exit 1
    chmod 0640 /var/www/html/config.php || exit 1
    record_change 'secured /var/www/html/config.php as www-data:www-data mode 0640'
    printf 'Sensitive file: /var/www/html/config.php set to 0640 (owner www-data)\n'
fi

for private_key in /home/devops/.ssh/id_rsa /home/devops/.ssh/id_ed25519 \
    /home/devops/.ssh/id_ecdsa /home/devops/.ssh/id_dsa; do
    [ -f "$private_key" ] || continue
    mode=$(stat -c '%a' "$private_key") || exit 1
    if (( (8#$mode) & 0077 )); then
        backup_path "$private_key" || exit 1
        chmod 0600 "$private_key" || exit 1
        record_change "secured $private_key as mode 0600; saved mode=$mode"
        printf 'SSH key: %s %s to 600\n' "$private_key" "$mode"
    fi
done

application_env=/var/www/html/.env
secure_env=/etc/novatech/app.env
if [ -f "$application_env" ] && [ ! -L "$application_env" ]; then
    if [ -e "$secure_env" ]; then
        printf '[ERROR] Refusing to overwrite existing %s.\n' "$secure_env" >&2
        exit 1
    fi
    backup_path "$application_env" || exit 1
    install -d -o root -g www-data -m 0750 /etc/novatech || exit 1
    install -o root -g www-data -m 0640 "$application_env" "$secure_env" || exit 1
    ln -s "$secure_env" "$application_env.new" || exit 1
    mv -Tf "$application_env.new" "$application_env" || exit 1
    record_change 'moved web environment file to /etc/novatech/app.env and linked it'
    printf 'Credential exposure: %s moved to %s; compatibility symlink created\n' \
        "$application_env" "$secure_env"
elif [ -L "$application_env" ] && [ "$(readlink "$application_env")" = "$secure_env" ]; then
    printf 'Credential exposure: environment file already secured\n'
fi

printf 'All permission issues remediated.\n'
printf 'Backups: %s\nAudit log: %s\n' "$backup_directory" "$log_file"
