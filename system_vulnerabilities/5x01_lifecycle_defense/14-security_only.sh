#!/bin/bash

# Je garde uniquement les origines de sécurité unattended-upgrades.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi
for command_name in awk apt-config install mktemp cp date mkdir grep; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise absente: %s\n' "$command_name" >&2
        exit 1
    fi
done

config_file=/etc/apt/apt.conf.d/50unattended-upgrades
backup_directory=/var/backups/lifecycle-defense
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
mkdir -p "$backup_directory" || exit 1
if [ -f "$config_file" ]; then
    cp -a -- "$config_file" \
        "$backup_directory/50unattended-upgrades.$timestamp" || {
        printf '[ERROR] Sauvegarde de la configuration impossible.\n' >&2
        exit 1
    }
fi

temporary_file=$(mktemp) || exit 1
trap 'rm -f -- "$temporary_file"' EXIT
if [ -f "$config_file" ]; then
    awk '
        /^[[:space:]]*Unattended-Upgrade::Allowed-Origins[[:space:]]*\{/ {
            in_origins = 1
            depth = 1
            next
        }
        in_origins {
            opening = gsub(/\{/, "{")
            closing = gsub(/\}/, "}")
            depth += opening - closing
            if (depth <= 0) in_origins = 0
            next
        }
        { print }
    ' "$config_file" > "$temporary_file" || {
        printf '[ERROR] Lecture de la configuration APT échouée.\n' >&2
        exit 1
    }
fi

cat >> "$temporary_file" <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
    // "${distro_id}:${distro_codename}-updates";
    // "${distro_id}:${distro_codename}-backports";
};
EOF

if ! grep -Fq '"${distro_id}:${distro_codename}-security"' \
    "$temporary_file" ||
    ! grep -Fq '// "${distro_id}:${distro_codename}-updates";' \
        "$temporary_file" ||
    ! grep -Fq '// "${distro_id}:${distro_codename}-backports";' \
        "$temporary_file"; then
    printf '[ERROR] Les origines APT préparées sont incomplètes.\n' >&2
    exit 1
fi

install -o root -g root -m 0644 "$temporary_file" "$config_file" || {
    printf '[ERROR] Écriture de la configuration échouée.\n' >&2
    exit 1
}
effective_config=$(apt-config dump) || {
    printf '[ERROR] Validation par apt-config échouée.\n' >&2
    exit 1
}
if ! grep -Fq '"${distro_id}:${distro_codename}-security"' \
    <<< "$effective_config"; then
    printf '[ERROR] Origine sécurité absente de la configuration active.\n' \
        >&2
    exit 1
fi
if grep -E 'Unattended-Upgrade::Allowed-Origins::.*-(updates|backports)' \
    <<< "$effective_config"; then
    printf '[ERROR] Une origine non sécuritaire reste active.\n' >&2
    exit 1
fi

printf '=== Security-Only Configuration ===\n\n'
printf 'Configuring %s...\n\n' "$config_file"
printf 'Allowed-Origins:\n'
printf '  [ENABLED]  "${distro_id}:${distro_codename}-security"\n'
printf '  [ENABLED]  "${distro_id}ESMApps:${distro_codename}-apps-security"\n'
printf '  [ENABLED]  "${distro_id}ESM:${distro_codename}-infra-security"\n'
printf '  [DISABLED] "${distro_id}:${distro_codename}-updates"\n'
printf '  [DISABLED] "${distro_id}:${distro_codename}-backports"\n'
printf '\nSecurity-only filter applied.\n'
printf 'Only security updates will be installed automatically.\n'
