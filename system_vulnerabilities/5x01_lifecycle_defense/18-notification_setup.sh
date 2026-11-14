#!/bin/bash

# Je conserve un journal dédié des opérations et tentatives APT.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi

log_file=/var/log/lifecycle-defense.log
logrotate_file=/etc/logrotate.d/lifecycle-defense
notification_file=/etc/apt/apt.conf.d/52lifecycle-notifications
backup_directory=/var/backups/lifecycle-defense
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
mkdir -p "$backup_directory" || exit 1
for file in "$log_file" "$logrotate_file" "$notification_file"; do
    if [ -f "$file" ]; then
        cp -a -- "$file" "$backup_directory/$(basename "$file").$timestamp" || {
            printf '[ERROR] Sauvegarde impossible: %s\n' "$file" >&2
            exit 1
        }
    fi
done
touch "$log_file" || exit 1
chown root:adm "$log_file" || exit 1
chmod 0640 "$log_file" || exit 1
cat > "$logrotate_file" <<'EOF'
/var/log/lifecycle-defense.log {
    weekly
    rotate 12
    compress
    missingok
    notifempty
    create 0640 root adm
}
EOF
chmod 0644 "$logrotate_file" || exit 1
cat > "$notification_file" <<'EOF'
Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailOnlyOnError "true";
EOF
chmod 0644 "$notification_file" || exit 1
if command -v logger >/dev/null 2>&1; then
    logger -p authpriv.notice -t lifecycle-defense \
        'Patch management audit logging configured'
fi
printf 'Audit log: %s (root:adm, mode 0640)\n' "$log_file"
printf 'Rotation: %s\n' "$logrotate_file"
printf 'APT failure notifications: root via local mail transport\n'
if ! command -v sendmail >/dev/null 2>&1; then
    printf '[WARN] Aucun MTA détecté, les courriels ne seront pas remis.\n'
fi
