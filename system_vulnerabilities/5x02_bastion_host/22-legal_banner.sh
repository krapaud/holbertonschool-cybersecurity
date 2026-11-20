#!/bin/bash
# Je configure la bannière SSH sans laisser une configuration invalide.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Lance ce script avec sudo dans la VM de laboratoire.\n' \
        >&2
    exit 1
fi

required_commands=(awk cat cp date install mkdir mktemp rm sshd stat systemctl)
for command_name in "${required_commands[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise introuvable: %s\n' \
            "$command_name" >&2
        exit 1
    fi
done

config_file=/etc/ssh/sshd_config
banner_file=/etc/issue.net
backup_directory=/var/backups/hardening
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')

if [ ! -f "$config_file" ] || [ ! -w "$config_file" ]; then
    printf '[ERROR] Configuration SSH absente ou non modifiable.\n' >&2
    exit 1
fi

ssh_service=
for candidate_service in ssh.service sshd.service; do
    if systemctl is-active --quiet "$candidate_service"; then
        ssh_service=$candidate_service
        break
    fi
done
if [ -z "$ssh_service" ]; then
    printf '[ERROR] Aucun service SSH actif à recharger.\n' >&2
    exit 1
fi

temporary_directory=$(mktemp -d) || {
    printf '[ERROR] Impossible de créer un dossier temporaire.\n' >&2
    exit 1
}
trap 'rm -rf -- "$temporary_directory"' EXIT

config_backup=$backup_directory/sshd_config.$timestamp
banner_backup=$backup_directory/issue.net.$timestamp

restore_files()
{
    cp -a -- "$config_backup" "$config_file" || return 1
    if [ -e "$banner_backup" ]; then
        cp -a -- "$banner_backup" "$banner_file"
    else
        rm -f -- "$banner_file"
    fi
}

reload_ssh()
{
    if [ "$ssh_service" = ssh.service ]; then
        systemctl reload ssh
    else
        systemctl reload sshd
    fi
}

new_banner=$temporary_directory/issue.net
new_config=$temporary_directory/sshd_config
printf '%s\n' \
    '=====================================' \
    'AUTHORIZED ACCESS ONLY' \
    '' \
    'This system is the property of NovaTech Solutions.' \
    'Unauthorized access is prohibited and will be prosecuted.' \
    'All activities are monitored and logged.' \
    '=====================================' > "$new_banner" || {
        printf '[ERROR] Préparation de la bannière impossible.\n' >&2
        exit 1
    }

if ! mkdir -p "$backup_directory" ||
    ! cp -a -- "$config_file" "$config_backup"; then
    printf '[ERROR] Sauvegarde de la configuration SSH impossible.\n' >&2
    exit 1
fi
if [ -e "$banner_file" ] &&
    ! cp -a -- "$banner_file" "$banner_backup"; then
    printf '[ERROR] Sauvegarde de la bannière existante impossible.\n' >&2
    exit 1
fi

printf '=== Legal Banner Configuration ===\n\n'
printf 'Creating banner in %s...\n\n' "$banner_file"
if ! install -o root -g root -m 0644 "$new_banner" "$banner_file"; then
    restore_files || true
    printf '[ERROR] Écriture de %s impossible.\n' "$banner_file" >&2
    exit 1
fi

printf 'Banner content:\n'
cat "$banner_file"

# Je place Banner dans la partie globale, avant tout bloc Match.
if ! awk '
    BEGIN { global_found = 0; in_match = 0 }
    /^[[:space:]]*Match[[:space:]]/ {
        if (!global_found) {
            print "Banner /etc/issue.net"
            global_found = 1
        }
        in_match = 1
    }
    /^[[:space:]]*[Bb]anner[[:space:]]+/ {
        print "Banner /etc/issue.net"
        if (!in_match) {
            global_found = 1
        }
        next
    }
    { print }
    END {
        if (!global_found) print "Banner /etc/issue.net"
    }
' "$config_file" > "$new_config"; then
    restore_files || true
    printf '[ERROR] Préparation de la configuration SSH impossible.\n' >&2
    exit 1
fi

config_owner=$(stat -c '%U' "$config_file") || config_owner=root
config_group=$(stat -c '%G' "$config_file") || config_group=root
config_mode=$(stat -c '%a' "$config_file") || config_mode=0644

printf '\nConfiguring SSH to display banner...\n'
if ! install -o "$config_owner" -g "$config_group" \
    -m "$config_mode" "$new_config" "$config_file"; then
    restore_files || true
    printf '[ERROR] Mise à jour de la configuration SSH impossible.\n' >&2
    exit 1
fi

if ! sshd -t -f "$config_file"; then
    restore_files || true
    printf '[ERROR] Config sshd invalide, restauration effectuée.\n' \
        >&2
    exit 1
fi

effective_banner=$(sshd -T -f "$config_file" 2>/dev/null |
    awk 'tolower($1) == "banner" { print $2; exit }') || effective_banner=
if [ "$effective_banner" != "$banner_file" ]; then
    restore_files || true
    printf '[ERROR] La directive Banner effective ne correspond pas.\n' >&2
    exit 1
fi
printf '  Banner %s: Enabled\n' "$banner_file"

printf '\nReloading SSH...\n'
if ! reload_ssh; then
    restore_files || true
    reload_ssh >/dev/null 2>&1 || true
    printf '[ERROR] Rechargement de SSH échoué.\n' >&2
    exit 1
fi

printf '\nVerification:\n'
if [ -s "$banner_file" ]; then
    printf '  %s: EXISTS ✓\n' "$banner_file"
else
    printf '[ERROR] Bannière absente ou vide.\n' >&2
    exit 1
fi
effective_banner=$(sshd -T -f "$config_file" 2>/dev/null |
    awk 'tolower($1) == "banner" { print $2; exit }') || effective_banner=
if [ "$effective_banner" = "$banner_file" ]; then
    printf '  SSH Banner config: ENABLED ✓\n'
else
    printf '[ERROR] Bannière SSH non active dans la configuration.\n' \
        >&2
    exit 1
fi

printf '\nLegal banner configured.\n'
