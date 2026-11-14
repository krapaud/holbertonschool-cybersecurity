#!/bin/bash

# J’active les mises à jour automatiques déjà installées sur Ubuntu.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi
if ! dpkg-query -W -f='${db:Status-Status}' unattended-upgrades \
    2>/dev/null | grep -q installed; then
    printf '[ERROR] unattended-upgrades doit être installé au préalable.\n' >&2
    exit 1
fi

config_file=/etc/apt/apt.conf.d/20auto-upgrades
backup_directory=/var/backups/lifecycle-defense
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
mkdir -p "$backup_directory" || exit 1
if [ -f "$config_file" ]; then
    cp -a -- "$config_file" "$backup_directory/20auto-upgrades.$timestamp" || {
        printf '[ERROR] Sauvegarde de la configuration impossible.\n' >&2
        exit 1
    }
fi
temporary_file=$(mktemp) || exit 1
trap 'rm -f -- "$temporary_file"' EXIT
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
if ! unattended-upgrade --dry-run --debug >/dev/null 2>&1; then
    printf '[ERROR] La vérification unattended-upgrades a échoué.\n' >&2
    exit 1
fi
if ! systemctl enable --now apt-daily.timer apt-daily-upgrade.timer; then
    printf '[ERROR] Impossible d’activer les timers APT.\n' >&2
    exit 1
fi
for timer in apt-daily.timer apt-daily-upgrade.timer; do
    if ! systemctl is-enabled --quiet "$timer" ||
        ! systemctl is-active --quiet "$timer"; then
        printf '[ERROR] Le timer APT %s n’est pas actif et activé.\n' \
            "$timer" >&2
        exit 1
    fi
done
printf 'unattended-upgrades: enabled\n'
printf 'Configuration: %s\n' "$config_file"
printf 'Timers: apt-daily.timer and apt-daily-upgrade.timer enabled and active\n'
printf 'Dry run: passed\n'
