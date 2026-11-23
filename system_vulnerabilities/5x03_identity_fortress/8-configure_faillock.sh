#!/bin/bash
# Je configure faillock pour limiter les essais de connexion échoués.

set -o pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

if [ "$(id -u)" -ne 0 ]; then
    error 'Run this script with sudo to update PAM.'
fi

for command_name in awk cp find grep install mktemp rm stat; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done

pam_auth=/etc/pam.d/common-auth
pam_account=/etc/pam.d/common-account
faillock_config=/etc/security/faillock.conf

for pam_file in "$pam_auth" "$pam_account"; do
    [ -r "$pam_file" ] || error "PAM file is missing: $pam_file"
    [ -w "$pam_file" ] || error "PAM file is not writable: $pam_file"
done

if ! find /lib /usr/lib -type f -name pam_faillock.so \
    -print -quit 2>/dev/null | grep -q .; then
    error 'pam_faillock.so is unavailable. Install libpam-modules first.'
fi

backup_file()
{
    local source_file=$1
    local backup_path=$2

    if [ ! -e "$backup_path" ] && ! cp -a -- "$source_file" "$backup_path"; then
        error "Could not create backup: $backup_path"
    fi
}

temporary_directory=$(mktemp -d) || \
    error 'Could not create a temporary directory.'
trap 'rm -rf -- "$temporary_directory"' EXIT

new_auth=$temporary_directory/common-auth
new_account=$temporary_directory/common-account
new_faillock=$temporary_directory/faillock.conf

# Je sauvegarde les fichiers PAM avant toute modification.
backup_file "$pam_auth" "$pam_auth.bak"
backup_file "$pam_account" "$pam_account.bak"
if [ -e "$faillock_config" ]; then
    backup_file "$faillock_config" "$faillock_config.bak"
fi

# Je retire les anciennes lignes faillock puis place les contrôles autour de pam_unix.
if ! awk '
    /^[[:space:]]*auth[[:space:]].*pam_faillock[.]so/ { next }
    !preauth_added && /^[[:space:]]*auth[[:space:]].*pam_unix[.]so/ {
        print "auth required pam_faillock.so preauth"
        preauth_added = 1
    }
    { print }
    /^[[:space:]]*auth[[:space:]].*pam_unix[.]so/ {
        print "auth [default=die] pam_faillock.so authfail"
        print "auth sufficient pam_faillock.so authsucc"
    }
    END { if (!preauth_added) exit 1 }
' "$pam_auth" > "$new_auth"; then
    error 'Could not prepare common-auth faillock rules.'
fi

# La règle account tient aussi compte des comptes déjà verrouillés.
if ! awk '
    /^[[:space:]]*account[[:space:]].*pam_faillock[.]so/ { next }
    !rule_added && /^[[:space:]]*account[[:space:]].*pam_unix[.]so/ {
        print "account required pam_faillock.so"
        rule_added = 1
    }
    { print }
    END { if (!rule_added) exit 1 }
' "$pam_account" > "$new_account"; then
    error 'Could not prepare common-account faillock rule.'
fi

# Je conserve les autres paramètres éventuels de faillock.conf.
if [ -r "$faillock_config" ]; then
    if ! awk '
        /^[[:space:]]*(deny|unlock_time|fail_interval)[[:space:]]*=/ { next }
        { print }
    ' "$faillock_config" > "$new_faillock"; then
        error 'Could not read faillock.conf.'
    fi
else
    : > "$new_faillock"
fi
cat >> "$new_faillock" <<'EOF'
deny = 5
unlock_time = 900
fail_interval = 900
EOF

auth_owner=$(stat -c '%U' "$pam_auth") || auth_owner=root
auth_group=$(stat -c '%G' "$pam_auth") || auth_group=root
auth_mode=$(stat -c '%a' "$pam_auth") || auth_mode=0644
account_owner=$(stat -c '%U' "$pam_account") || account_owner=root
account_group=$(stat -c '%G' "$pam_account") || account_group=root
account_mode=$(stat -c '%a' "$pam_account") || account_mode=0644

printf '=== Account Lockout Configuration ===\n\n'
printf 'Configuring pam_faillock...\n\n'
printf 'Updating %s...\n' "$pam_auth"
if ! install -o "$auth_owner" -g "$auth_group" -m "$auth_mode" \
    "$new_auth" "$pam_auth"; then
    cp -a -- "$pam_auth.bak" "$pam_auth" 2>/dev/null || true
    error "Could not update $pam_auth"
fi
printf '  pam_faillock.so preauth: Added\n'
printf '  pam_faillock.so authfail: Added\n'
printf '  pam_faillock.so authsucc: Added\n'

printf '\nUpdating %s...\n' "$pam_account"
if ! install -o "$account_owner" -g "$account_group" \
    -m "$account_mode" "$new_account" "$pam_account"; then
    cp -a -- "$pam_account.bak" "$pam_account" 2>/dev/null || true
    cp -a -- "$pam_auth.bak" "$pam_auth" 2>/dev/null || true
    error "Could not update $pam_account"
fi
printf '  pam_faillock.so: Added\n'

if ! install -o root -g root -m 0644 "$new_faillock" "$faillock_config"; then
    cp -a -- "$pam_account.bak" "$pam_account" 2>/dev/null || true
    cp -a -- "$pam_auth.bak" "$pam_auth" 2>/dev/null || true
    error "Could not update $faillock_config"
fi

# Je vérifie les règles installées sans verrouiller un vrai compte de test.
if ! grep -Eq '^[[:space:]]*auth[[:space:]]+required[[:space:]]+pam_faillock[.]so[[:space:]]+preauth' \
    "$pam_auth" || \
    ! grep -Eq '^[[:space:]]*auth[[:space:]].*pam_faillock[.]so[[:space:]]+authfail' \
    "$pam_auth" || \
    ! grep -Eq '^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_faillock[.]so[[:space:]]+authsucc' \
    "$pam_auth" || \
    ! grep -Eq '^[[:space:]]*account[[:space:]]+required[[:space:]]+pam_faillock[.]so' \
    "$pam_account" || \
    ! grep -Eq '^[[:space:]]*deny[[:space:]]*=[[:space:]]*5([[:space:]]|$)' \
    "$faillock_config" || \
    ! grep -Eq '^[[:space:]]*unlock_time[[:space:]]*=[[:space:]]*900([[:space:]]|$)' \
    "$faillock_config" || \
    ! grep -Eq '^[[:space:]]*fail_interval[[:space:]]*=[[:space:]]*900([[:space:]]|$)' \
    "$faillock_config"; then
    cp -a -- "$pam_account.bak" "$pam_account" 2>/dev/null || true
    cp -a -- "$pam_auth.bak" "$pam_auth" 2>/dev/null || true
    error 'Faillock configuration verification failed; PAM backups were restored.'
fi

printf '\nConfiguration:\n'
printf '  deny = 5 (lock after 5 failures)\n'
printf '  unlock_time = 900 (15 minutes)\n'
printf '  fail_interval = 900 (count failures within 15 min)\n'
printf '\nCreating %s...\n' "$faillock_config"
printf '  Configuration written\n'
printf '\nTesting...\n'
printf '  PAM rules and lockout settings: VERIFIED\n'
printf '  No real account was locked during this check.\n'
printf '\nAccount lockout: ACTIVE\n'
