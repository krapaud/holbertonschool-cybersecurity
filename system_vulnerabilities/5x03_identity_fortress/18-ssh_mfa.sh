#!/bin/bash

# Je configure PAM et SSH pour demander une clé puis un code TOTP.

set -o pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

if [ "$(id -u)" -ne 0 ]; then
    error 'Run this script with sudo from an account that already has SSH key access and TOTP configured.'
fi
if [ -z "${SUDO_USER:-}" ] || [ "$SUDO_USER" = root ]; then
    error 'Run this script with sudo from the regular account that will use SSH MFA.'
fi

for command_name in awk cp date getent grep install mktemp rm sshd stat systemctl; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done

pam_file=/etc/pam.d/sshd
ssh_file=/etc/ssh/sshd_config
pam_backup=$pam_file.backup
ssh_backup=$ssh_file.backup
[ -r "$pam_file" ] || error "PAM configuration is missing or unreadable: $pam_file"
[ -r "$ssh_file" ] || error "SSH configuration is missing or unreadable: $ssh_file"

# Je vérifie que le compte administrateur a déjà son secret et une clé.
user_record=$(getent passwd "$SUDO_USER") || \
    error "Could not find account $SUDO_USER."
IFS=: read -r account_name _ _ _ _ user_home _ <<< "$user_record"
[ -n "$user_home" ] && [ -d "$user_home" ] || \
    error "Home directory is unavailable for $SUDO_USER."
[ -s "$user_home/.google_authenticator" ] || \
    error "TOTP is not set up for $SUDO_USER. Run 17-setup_user_totp.sh first."
[ -s "$user_home/.ssh/authorized_keys" ] || \
    error "No authorized SSH key found for $SUDO_USER. Deploy a key before enabling MFA."

ssh_service=ssh.service
if ! systemctl is-active --quiet "$ssh_service"; then
    ssh_service=sshd.service
fi
systemctl is-active --quiet "$ssh_service" || \
    error 'The SSH service is not active.'

temporary_directory=$(mktemp -d) || \
    error 'Could not create a temporary directory.'
trap 'rm -rf -- "$temporary_directory"' EXIT
new_pam=$temporary_directory/sshd.pam
new_ssh=$temporary_directory/sshd_config
old_pam=$temporary_directory/sshd.pam.previous
old_ssh=$temporary_directory/sshd_config.previous
effective_config=$temporary_directory/effective-config

# Je conserve les sauvegardes demandées et une copie temporaire pour rollback.
cp -a -- "$pam_file" "$old_pam" || error "Could not snapshot $pam_file."
cp -a -- "$ssh_file" "$old_ssh" || error "Could not snapshot $ssh_file."
if [ ! -e "$pam_backup" ]; then
    cp -a -- "$pam_file" "$pam_backup" || error "Could not back up $pam_file."
fi
if [ ! -e "$ssh_backup" ]; then
    cp -a -- "$ssh_file" "$ssh_backup" || error "Could not back up $ssh_file."
fi

printf '=== SSH Multi-Factor Authentication ===\n\n'
printf 'Backing up configurations...\n'
printf '  %s\n' "$pam_backup" "$ssh_backup"

# Je remplace l'authentification par mot de passe SSH par le contrôle TOTP.
if ! awk '
    /^[[:space:]]*#/ { print; next }
    /pam_google_authenticator[.]so/ { next }
    /^[[:space:]]*@include[[:space:]]+common-auth([[:space:]]|$)/ {
        print "# Authentification SSH par mot de passe remplacée par le TOTP."
        next
    }
    { print }
' "$pam_file" > "$new_pam"; then
    error 'Could not prepare the PAM configuration.'
fi
temporary_pam=$temporary_directory/sshd.pam.final
{
    printf '%s\n' 'auth required pam_google_authenticator.so'
    cat "$new_pam"
} > "$temporary_pam" || error 'Could not write the new PAM configuration.'

# Je place les options globales avant les Includes et évite les doublons actifs.
if ! awk '
    BEGIN {
        print "PubkeyAuthentication yes"
        print "UsePAM yes"
        print "ChallengeResponseAuthentication yes"
        print "KbdInteractiveAuthentication yes"
        print "AuthenticationMethods publickey,keyboard-interactive"
        managed["pubkeyauthentication"] = 1
        managed["usepam"] = 1
        managed["challengeresponseauthentication"] = 1
        managed["kbdinteractiveauthentication"] = 1
        managed["authenticationmethods"] = 1
    }
    /^[[:space:]]*#/ { print; next }
    tolower($1) in managed { next }
    { print }
' "$ssh_file" > "$new_ssh"; then
    error 'Could not prepare the SSH configuration.'
fi

pam_owner=$(stat -c '%U' "$pam_file") || pam_owner=root
pam_group=$(stat -c '%G' "$pam_file") || pam_group=root
pam_mode=$(stat -c '%a' "$pam_file") || pam_mode=0644
ssh_owner=$(stat -c '%U' "$ssh_file") || ssh_owner=root
ssh_group=$(stat -c '%G' "$ssh_file") || ssh_group=root
ssh_mode=$(stat -c '%a' "$ssh_file") || ssh_mode=0644

restore_config()
{
    install -o "$pam_owner" -g "$pam_group" -m "$pam_mode" "$old_pam" "$pam_file" || return 1
    install -o "$ssh_owner" -g "$ssh_group" -m "$ssh_mode" "$old_ssh" "$ssh_file" || return 1
    sshd -t -f "$ssh_file" && systemctl reload "$ssh_service"
}

printf '\nConfiguring %s...\n' "$pam_file"
printf '  Adding: auth required pam_google_authenticator.so\n'
if ! install -o "$pam_owner" -g "$pam_group" -m "$pam_mode" "$temporary_pam" "$pam_file"; then
    error "Could not update $pam_file."
fi

printf '\nConfiguring %s...\n' "$ssh_file"
printf '  ChallengeResponseAuthentication: no -> yes\n'
printf '  AuthenticationMethods: publickey,keyboard-interactive\n'
if ! install -o "$ssh_owner" -g "$ssh_group" -m "$ssh_mode" "$new_ssh" "$ssh_file"; then
    restore_config || true
    error "Could not update $ssh_file; previous configurations restored."
fi

printf '\nValidating configuration...\n'
if ! sshd -t -f "$ssh_file"; then
    restore_config || true
    error 'sshd configuration is invalid; previous configurations restored.'
fi
if ! grep -Eq '^[[:space:]]*auth[[:space:]]+required[[:space:]]+pam_google_authenticator[.]so([[:space:]]|$)' "$pam_file"; then
    restore_config || true
    error 'The required Google Authenticator PAM rule is missing; previous configurations restored.'
fi
if ! sshd -T -f "$ssh_file" > "$effective_config" 2>/dev/null || \
    ! awk '
        $1 == "pubkeyauthentication" && $2 == "yes" { key = 1 }
        $1 == "usepam" && $2 == "yes" { pam = 1 }
        $1 == "kbdinteractiveauthentication" && $2 == "yes" { interactive = 1 }
        $1 == "authenticationmethods" && $2 == "publickey,keyboard-interactive" { methods = 1 }
        END { exit !(key && pam && interactive && methods) }
    ' "$effective_config"; then
    restore_config || true
    error 'Effective SSH settings do not require both factors; previous configurations restored.'
fi
printf '  sshd -t: OK\n'
printf '  PAM syntax: OK (module rule verified)\n'

printf '\nReloading SSH...\n'
if ! systemctl reload "$ssh_service"; then
    restore_config || true
    error 'SSH reload failed; previous configurations restored.'
fi
printf '  %s: Reloaded\n' "$ssh_service"

printf '\nSSH MFA Configuration:\n'
printf '  First factor: SSH Public Key\n'
printf '  Second factor: TOTP Code (Google Authenticator)\n'
printf '\nUsers must now provide BOTH key AND TOTP code to log in.\n'
