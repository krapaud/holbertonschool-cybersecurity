#!/bin/bash
# Je coupe l’authentification SSH par mot de passe après test d’accès par clé.

set -o pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

if [ "$(id -u)" -ne 0 ]; then
    error 'Run this script with sudo from the SSH account being tested.'
fi
if [ -z "${SUDO_USER:-}" ] || [ "$SUDO_USER" = root ]; then
    error 'Run this script with sudo from a regular account with SSH key access.'
fi

for command_name in awk cp date getent install mktemp rm runuser ssh \
    sshd stat systemctl; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done

config_file=/etc/ssh/sshd_config
[ -r "$config_file" ] || error "SSH configuration is unreadable: $config_file"
account_record=$(getent passwd "$SUDO_USER") || \
    error "Could not find account $SUDO_USER."
IFS=: read -r account_name _ _ _ _ account_home _ <<< "$account_record"
[ -n "$account_home" ] && [ -d "$account_home" ] || \
    error "Home directory is unavailable for $SUDO_USER."

# Je récupère le port effectif pour tester l’accès SSH local.
ssh_port=$(sshd -T 2>/dev/null | awk '$1 == "port" { print $2; exit }')
ssh_port=${ssh_port:-22}
check_key_access()
{
    runuser -u "$SUDO_USER" -- ssh -F /dev/null \
        -o BatchMode=yes \
        -o PreferredAuthentications=publickey \
        -o PasswordAuthentication=no \
        -o KbdInteractiveAuthentication=no \
        -o StrictHostKeyChecking=accept-new \
        -p "$ssh_port" "$SUDO_USER@127.0.0.1" true \
        >/dev/null 2>&1
}

printf '=== Disable SSH Password Authentication ===\n\n'
printf 'Pre-flight checks:\n'
printf '  Current user has SSH key: CHECKING...\n'
if ! check_key_access; then
    error 'Key-based SSH access to localhost failed; no configuration was changed.'
fi
printf '  Key-based auth working: YES ✓\n'
printf '\nWARNING: This will disable password authentication.\n'
printf 'Ensure you have working key-based access!\n'

ssh_service=ssh.service
if ! systemctl is-active --quiet "$ssh_service" && \
    systemctl is-active --quiet sshd.service; then
    ssh_service=sshd.service
fi

timestamp=$(date -u '+%Y%m%d%H%M%S')
backup_file=/etc/ssh/sshd_config.backup.$timestamp
temporary_directory=$(mktemp -d) || \
    error 'Could not create a temporary directory.'
trap 'rm -rf -- "$temporary_directory"' EXIT
new_config=$temporary_directory/sshd_config
previous_config=$temporary_directory/sshd_config.previous
cp -a -- "$config_file" "$previous_config" || \
    error "Could not prepare a rollback copy of $config_file."
if [ ! -e /etc/ssh/sshd_config.backup ]; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup || \
        error 'Could not create the initial sshd_config backup.'
fi
cp -a -- "$config_file" "$backup_file" || \
    error "Could not back up $config_file."

printf '\nBacking up sshd_config...\n'
printf '  %s\n' "$backup_file"

reload_ssh()
{
    systemctl reload ssh || systemctl reload sshd.service
}

if ! awk '
    BEGIN {
        print "PasswordAuthentication no"
        print "ChallengeResponseAuthentication no"
        print "KbdInteractiveAuthentication no"
        print "PubkeyAuthentication yes"
        print "UsePAM yes"
        managed["passwordauthentication"] = 1
        managed["challengeresponseauthentication"] = 1
        managed["kbdinteractiveauthentication"] = 1
        managed["pubkeyauthentication"] = 1
        managed["usepam"] = 1
    }
    /^[[:space:]]*#/ { print; next }
    tolower($1) in managed { next }
    { print }
' "$config_file" > "$new_config"; then
    error 'Could not prepare the SSH configuration update.'
fi

config_owner=$(stat -c '%U' "$config_file") || config_owner=root
config_group=$(stat -c '%G' "$config_file") || config_group=root
config_mode=$(stat -c '%a' "$config_file") || config_mode=0644
printf '\nModifying %s...\n' "$config_file"
printf '  PasswordAuthentication: yes → no\n'
printf '  ChallengeResponseAuthentication: yes → no\n'
printf '  UsePAM: yes (preserving for account checks)\n'
if ! install -o "$config_owner" -g "$config_group" -m "$config_mode" \
    "$new_config" "$config_file"; then
    error "Could not update $config_file."
fi

restore_config()
{
    install -o "$config_owner" -g "$config_group" -m "$config_mode" \
        "$previous_config" "$config_file"
    sshd -t -f "$config_file" && reload_ssh
}

effective_config=$temporary_directory/effective-config
if ! sshd -t -f "$config_file"; then
    restore_config || true
    error 'sshd configuration validation failed; previous config restored.'
fi
if ! sshd -T -f "$config_file" > "$effective_config" 2>/dev/null || \
    ! awk '$1 == "passwordauthentication" && $2 == "no" { p = 1 }
        $1 == "kbdinteractiveauthentication" && $2 == "no" { c = 1 }
        $1 == "pubkeyauthentication" && $2 == "yes" { k = 1 }
        $1 == "usepam" && $2 == "yes" { m = 1 }
        END { exit !(p && c && k && m) }' "$effective_config"; then
    restore_config || true
    error 'Effective SSH settings are unsafe; previous config restored.'
fi
printf '\nValidating configuration...\n'
printf '  sshd -t: Configuration OK\n'

printf '\nReloading SSH...\n'
if ! reload_ssh; then
    restore_config || true
    error 'SSH reload failed; previous config restored.'
fi
printf '  %s: Reloaded\n' "$ssh_service"

if ! check_key_access; then
    restore_config || true
    error 'Key-based SSH verification failed; previous config restored.'
fi
printf '\nVerification:\n'
printf '  Password auth: DISABLED\n'
printf '  Pubkey auth: ENABLED\n'
printf '\nSSH now requires key-based authentication.\n'
