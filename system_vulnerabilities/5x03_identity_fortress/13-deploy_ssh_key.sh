#!/bin/bash
# J’ajoute une clé publique au compte cible sans dupliquer ses clés existantes.

set -o pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

usage()
{
    printf 'Usage: %s "PUBLIC_KEY" [USER]\n' "${0##*/}" >&2
    exit 2
}

if [ "$(id -u)" -ne 0 ]; then
    error 'Run this script with sudo to deploy a key to another account.'
fi

for command_name in awk cat chmod chown getent grep install mkdir mktemp \
    mv rm ssh-keygen stat; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done

if [ $# -eq 0 ]; then
    usage
fi
if [ "$#" -gt 2 ]; then
    usage
fi

public_key=$1
target_user=${2:-auditor}
[[ "$target_user" =~ ^[a-zA-Z0-9_.-]+$ ]] || \
    error "Invalid target username: $target_user"
[[ "$public_key" != *$'\n'* && "$public_key" != *$'\r'* ]] || \
    error 'Provide exactly one public key line.'

account_record=$(getent passwd "$target_user") || \
    error "Target account not found: $target_user"
IFS=: read -r account_name _ account_uid account_gid _ account_home _ \
    <<< "$account_record"
[ "$account_name" = "$target_user" ] || \
    error "Could not resolve target account: $target_user"
[ -n "$account_home" ] && [ -d "$account_home" ] || \
    error "Target home directory is unavailable: $account_home"

temporary_directory=$(mktemp -d) || \
    error 'Could not create a temporary directory.'
trap 'rm -rf -- "$temporary_directory"' EXIT
key_file=$temporary_directory/public_key
printf '%s\n' "$public_key" > "$key_file" || \
    error 'Could not prepare the public key for validation.'
fingerprint=$(ssh-keygen -lf "$key_file" -E sha256 2>/dev/null | \
    awk '{ print $2; exit }')
[ -n "$fingerprint" ] || error 'The supplied public key is invalid.'

ssh_directory=$account_home/.ssh
authorized_keys=$ssh_directory/authorized_keys
ssh_directory_existed=1
if [ ! -d "$ssh_directory" ]; then
    ssh_directory_existed=0
fi
if ! mkdir -p -- "$ssh_directory"; then
    error "Could not create $ssh_directory."
fi
if ! chown "$account_uid:$account_gid" "$ssh_directory" || \
    ! chmod 700 "$ssh_directory"; then
    error "Could not secure $ssh_directory."
fi

temporary_keys=$(mktemp "$ssh_directory/.authorized_keys.XXXXXX") || \
    error "Could not prepare $authorized_keys."
if [ -f "$authorized_keys" ]; then
    if ! cat "$authorized_keys" > "$temporary_keys"; then
        error "Could not copy existing keys from $authorized_keys."
    fi
fi

printf '=== SSH Key Deployment ===\n\n'
printf 'Target user: %s\n\n' "$target_user"
if [ "$ssh_directory_existed" -eq 0 ]; then
    printf 'Creating .ssh directory if needed...\n'
    printf '  %s: Created\n' "$ssh_directory"
else
    printf '  %s: Already exists\n' "$ssh_directory"
fi
printf '  Permissions: 700\n\n'
printf 'Adding key to authorized_keys...\n'
printf '  Key fingerprint: %s\n' "$fingerprint"
if grep -Fxq -- "$public_key" "$authorized_keys" 2>/dev/null; then
    printf '  Key already present; no duplicate added\n'
else
    if ! printf '%s\n' "$public_key" >> "$temporary_keys"; then
        error "Could not add the key to $authorized_keys."
    fi
    if ! chown "$account_uid:$account_gid" "$temporary_keys" || \
        ! chmod 600 "$temporary_keys" || \
        ! mv -f -- "$temporary_keys" "$authorized_keys"; then
        error "Could not install $authorized_keys with secure permissions."
    fi
    printf '  Key added successfully\n'
fi

if [ ! -e "$authorized_keys" ]; then
    if ! install -o "$account_uid" -g "$account_gid" -m 0600 \
        "$temporary_keys" "$authorized_keys"; then
        error "Could not create $authorized_keys."
    fi
fi
if ! chown "$account_uid:$account_gid" "$authorized_keys" || \
    ! chmod 600 "$authorized_keys"; then
    error "Could not secure $authorized_keys."
fi

key_count=$(awk 'NF >= 2 && $1 ~ /^(ssh-|ecdsa-|sk-)/ { count++ }
    END { print count + 0 }' "$authorized_keys")
key_mode=$(stat -c '%a' "$authorized_keys") || \
    error "Could not verify $authorized_keys permissions."

printf '\nSetting permissions...\n'
printf '  authorized_keys: 600\n'
printf '\nVerification:\n'
printf '  Key count in authorized_keys: %s\n' "$key_count"
if [ "$key_mode" = 600 ]; then
    printf '  Permissions correct: YES\n'
else
    error "Unexpected authorized_keys permissions: $key_mode"
fi
printf '\nSSH key deployed.\n'
printf 'User can now authenticate with this key.\n'
