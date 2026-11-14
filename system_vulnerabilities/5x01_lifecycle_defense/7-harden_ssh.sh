#!/bin/bash

# Je sauvegarde SSH, applique les réglages puis valide avant rechargement.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi
for command_name in sshd systemctl; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise absente: %s\n' "$command_name" >&2
        exit 1
    fi
done

config_file=/etc/ssh/sshd_config
if [ ! -f "$config_file" ]; then
    printf '[ERROR] Configuration SSH introuvable: %s\n' "$config_file" >&2
    exit 1
fi
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
backup_file="$config_file.backup.$timestamp"
if ! cp -a -- "$config_file" "$backup_file"; then
    printf '[ERROR] Sauvegarde SSH impossible.\n' >&2
    exit 1
fi
printf 'Backup created: %s\n' "$backup_file"

include_file=/etc/ssh/sshd_config.d/99-lifecycle-defense.conf
include_backup=''
include_created=0
if grep -Eq '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' \
    "$config_file"; then
    mkdir -p /etc/ssh/sshd_config.d
    if [ -e "$include_file" ]; then
        include_backup="$include_file.backup.$timestamp"
        if ! cp -a "$include_file" "$include_backup"; then
            printf '[ERROR] Sauvegarde de la surcharge SSH impossible.\n' >&2
            exit 1
        fi
    else
        include_created=1
    fi
    printf '%s\n' \
        'PermitRootLogin no' \
        'PasswordAuthentication no' \
        'X11Forwarding no' \
        'MaxAuthTries 3' \
        'ClientAliveInterval 300' \
        'ClientAliveCountMax 2' > "$include_file"
    chmod 600 "$include_file"
else
    temporary_file=$(mktemp) || {
        printf '[ERROR] Impossible de créer le fichier temporaire SSH.\n' >&2
        exit 1
    }
    awk '
        BEGIN { keys["PermitRootLogin"] = "no"; keys["PasswordAuthentication"] = "no"; keys["X11Forwarding"] = "no"; keys["MaxAuthTries"] = "3"; keys["ClientAliveInterval"] = "300"; keys["ClientAliveCountMax"] = "2" }
        /^[[:space:]]*Match[[:space:]]/ && !inserted {
            for (key in keys) if (!seen[key]) print key " " keys[key]
            inserted = 1
        }
        /^[[:space:]]*#/ { print; next }
        {
            key = $1
            if (key in keys && !seen[key]) {
                print key " " keys[key]
                seen[key] = 1
            } else if (!(key in keys)) print
        }
        END {
            if (!inserted) for (key in keys) if (!seen[key]) print key " " keys[key]
        }
    ' "$config_file" > "$temporary_file" || {
        rm -f "$temporary_file"
        printf '[ERROR] Réécriture de sshd_config échouée.\n' >&2
        exit 1
    }
    cat "$temporary_file" > "$config_file"
    rm -f "$temporary_file"
fi

if ! sshd -t; then
    cp -a -- "$backup_file" "$config_file"
    if [ -n "$include_backup" ]; then
        cp -a -- "$include_backup" "$include_file"
    elif [ "$include_created" -eq 1 ]; then
        rm -f -- "$include_file"
    fi
    printf '[ERROR] Configuration invalide, restauration effectuée.\n' >&2
    exit 1
fi
printf 'Applying hardening measures...\n'
for setting in 'PermitRootLogin no' 'PasswordAuthentication no' \
    'X11Forwarding no' 'MaxAuthTries 3' 'ClientAliveInterval 300' \
    'ClientAliveCountMax 2'; do
    printf '  %s\n' "$setting"
done
if ! systemctl reload ssh; then
    cp -a -- "$backup_file" "$config_file"
    if [ -n "$include_backup" ]; then
        cp -a -- "$include_backup" "$include_file"
    elif [ "$include_created" -eq 1 ]; then
        rm -f -- "$include_file"
    fi
    systemctl reload ssh || true
    printf '[ERROR] Rechargement SSH échoué, configuration restaurée.\n' >&2
    exit 1
fi
printf 'Configuration test: OK\n'
printf 'sshd.service: Reloaded\n'
printf 'SSH hardened successfully.\n'
printf 'WARNING: Verify key-based login in a second session before closing this one.\n'
