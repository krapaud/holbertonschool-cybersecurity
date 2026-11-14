#!/bin/bash

# Je programme les tâches APT dans une fenêtre de maintenance nocturne.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi
if ! command -v systemctl >/dev/null 2>&1; then
    printf '[ERROR] systemctl est introuvable.\n' >&2
    exit 1
fi

dropin_directory=/etc/systemd/system/apt-daily.timer.d
upgrade_directory=/etc/systemd/system/apt-daily-upgrade.timer.d
backup_directory=/var/backups/lifecycle-defense
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
mkdir -p "$backup_directory" || exit 1
for timer_file in "$dropin_directory/override.conf" \
    "$upgrade_directory/override.conf"; do
    if [ -f "$timer_file" ]; then
        backup_name=$(basename "$(dirname "$timer_file")")
        cp -a -- "$timer_file" "$backup_directory/$backup_name.$timestamp" || {
            printf '[ERROR] Sauvegarde impossible: %s\n' "$timer_file" >&2
            exit 1
        }
    fi
done
install -d -m 0755 "$dropin_directory" "$upgrade_directory" || exit 1
cat > "$dropin_directory/override.conf" <<'EOF'
[Timer]
OnCalendar=
OnCalendar=*-*-* 02:00
RandomizedDelaySec=30m
Persistent=true
EOF
cat > "$upgrade_directory/override.conf" <<'EOF'
[Timer]
OnCalendar=
OnCalendar=*-*-* 03:00
RandomizedDelaySec=60m
Persistent=true
EOF
chmod 0644 "$dropin_directory/override.conf" \
    "$upgrade_directory/override.conf"
systemctl daemon-reload || exit 1
systemctl restart apt-daily.timer apt-daily-upgrade.timer || {
    printf '[ERROR] Impossible de redémarrer les timers APT.\n' >&2
    exit 1
}
systemctl list-timers apt-daily.timer apt-daily-upgrade.timer --no-pager
