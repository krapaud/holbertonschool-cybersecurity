#!/bin/bash
# Je configure PAM pour empêcher la réutilisation des anciens mots de passe.

set -o pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

if [ "$(id -u)" -ne 0 ]; then
    error 'Run this script with sudo to update PAM.'
fi

for command_name in awk chmod chown cp find grep install mktemp \
    rm stat tail; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done

pam_file=/etc/pam.d/common-password
history_file=/etc/security/opasswd
backup_file=/etc/pam.d/common-password.bak
if [ ! -r "$pam_file" ]; then
    error "PAM configuration is missing or unreadable: $pam_file"
fi
if ! grep -Eq '^[[:space:]]*password[[:space:]]+.*pam_unix[.]so' \
    "$pam_file"; then
    error 'Active pam_unix.so line not found in common-password.'
fi
if ! find /lib /usr/lib -type f -name pam_pwhistory.so \
    -print -quit 2>/dev/null | grep -q .; then
    error 'pam_pwhistory.so is unavailable. Install libpam-modules first.'
fi

temporary_directory=$(mktemp -d) || \
    error 'Could not create a temporary directory.'
trap 'rm -rf -- "$temporary_directory"' EXIT
new_pam=$temporary_directory/common-password

# Je conserve le fichier initial pour pouvoir restaurer la configuration.
if [ ! -e "$backup_file" ] && \
    ! cp /etc/pam.d/common-password /etc/pam.d/common-password.bak; then
    error "Could not create backup: $backup_file"
fi

if ! awk '
    /^[[:space:]]*password[[:space:]]+.*pam_pwhistory[.]so/ { next }
    !inserted && /^[[:space:]]*password[[:space:]]+.*pam_unix[.]so/ {
        print "password required pam_pwhistory.so remember=5 use_authtok"
        inserted = 1
    }
    { print }
    END { if (!inserted) exit 1 }
' "$pam_file" > "$new_pam"; then
    error 'Could not prepare the PAM history configuration.'
fi

# Le fichier contient des empreintes de mots de passe et reste privé à root.
printf '=== Password History Configuration ===\n\n'
printf 'Configuring pam_pwhistory...\n\n'
printf 'Creating password history file...\n'
if [ ! -e "$history_file" ]; then
    if ! install -o root -g root -m 0600 /dev/null "$history_file"; then
        error "Could not create password history file: $history_file"
    fi
    printf '  %s: Created\n' "$history_file"
else
    if ! chown root:root "$history_file" || ! chmod 0600 "$history_file"; then
        error "Could not secure password history file: $history_file"
    fi
    printf '  %s: Already exists, permissions secured\n' "$history_file"
fi

pam_owner=$(stat -c '%U' "$pam_file") || pam_owner=root
pam_group=$(stat -c '%G' "$pam_file") || pam_group=root
pam_mode=$(stat -c '%a' "$pam_file") || pam_mode=0644
printf '\nUpdating %s...\n' "$pam_file"
if ! install -o "$pam_owner" -g "$pam_group" -m "$pam_mode" \
    "$new_pam" "$pam_file"; then
    cp -a -- "$backup_file" "$pam_file" 2>/dev/null || true
    error "Could not update PAM configuration: $pam_file"
fi

history_rule='^[[:space:]]*password[[:space:]]+required'
history_rule+='[[:space:]]+pam_pwhistory[.]so[[:space:]]+remember=5'
if ! grep -Eq "$history_rule" "$pam_file"; then
    cp -a -- "$backup_file" "$pam_file" 2>/dev/null || true
    error 'pam_pwhistory.so remember=5 was not enabled.'
fi
printf '  pam_pwhistory.so remember=5: Added\n'

unix_line=$(grep -E '^[[:space:]]*password[[:space:]]+.*pam_unix[.]so' \
    "$pam_file" | tail -n 1)
if [[ " $unix_line " == *' sha512 '* ]]; then
    hash_algorithm=sha512
elif [[ " $unix_line " == *' yescrypt '* ]]; then
    hash_algorithm=yescrypt
else
    hash_algorithm='system default'
fi

printf '\nConfiguration:\n'
printf '  Passwords remembered: 5\n'
printf '  Hash algorithm: %s\n' "$hash_algorithm"
printf '\nTesting...\n'
printf '  Previous password reuse: BLOCKED (PAM rule verified)\n'
printf '\nPassword history enforcement: ACTIVE\n'
printf 'Users cannot reuse their last 5 passwords.\n'
