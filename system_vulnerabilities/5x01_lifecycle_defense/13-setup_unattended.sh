#!/bin/bash

# J’active les mises à jour automatiques déjà installées sur Ubuntu.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi
if ! command -v systemctl >/dev/null 2>&1 ||
    ! command -v unattended-upgrade >/dev/null 2>&1; then
    printf '[ERROR] systemctl ou unattended-upgrade est introuvable.\n' >&2
    exit 1
fi
if ! dpkg-query -W -f='${db:Status-Status}' unattended-upgrades \
    2>/dev/null | grep -q installed; then
    printf '[ERROR] unattended-upgrades doit être installé.\n' >&2
    exit 1
fi

config_file=/etc/apt/apt.conf.d/20auto-upgrades
backup_directory=/var/backups/lifecycle-defense
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
printf '=== Unattended-Upgrades Setup ===\n\n'
mkdir -p "$backup_directory" || exit 1
if [ -f "$config_file" ]; then
    cp -a -- "$config_file" "$backup_directory/20auto-upgrades.$timestamp" || {
        printf '[ERROR] Sauvegarde de la configuration impossible.\n' >&2
        exit 1
    }
fi
temporary_file=$(mktemp) || exit 1
trap 'rm -f -- "$temporary_file"' EXIT
printf 'Configuring %s...\n' "$config_file"
cat > "$temporary_file" <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF
install -o root -g root -m 0644 "$temporary_file" "$config_file" || {
    printf '[ERROR] Écriture de la configuration automatique échouée.\n' >&2
    exit 1
}
cat "$config_file"
printf '\nEnabling systemd timers...\n'
if ! systemctl enable apt-daily.timer apt-daily-upgrade.timer ||
    ! systemctl start apt-daily.timer apt-daily-upgrade.timer; then
    printf '[ERROR] Impossible d’activer ou démarrer les timers APT.\n' >&2
    exit 1
fi
for timer in apt-daily.timer apt-daily-upgrade.timer; do
    if ! systemctl is-enabled --quiet "$timer" ||
        ! systemctl is-active --quiet "$timer"; then
        printf '[ERROR] Le timer APT %s n’est pas actif et activé.\n' \
            "$timer" >&2
        exit 1
    fi
    printf '  %s: Enabled\n' "$timer"
done
if ! unattended-upgrade --dry-run --debug >/dev/null 2>&1; then
    printf '[ERROR] La vérification unattended-upgrades a échoué.\n' >&2
    exit 1
fi
next_run=$(systemctl show apt-daily-upgrade.timer \
    -p NextElapseUSecRealtime --value 2>/dev/null)
if [ -z "$next_run" ]; then
    next_run=$(systemctl list-timers --no-pager apt-daily-upgrade.timer \
        | awk 'NR == 2 { print $1, $2 }')
fi
printf '\nVerification:\n'
printf '  Unattended-upgrades: ACTIVE\n'
printf '  Next scheduled run: %s\n' "${next_run:-unavailable}"
printf '\nBasic setup complete.\n'
