#!/bin/bash
# Je force les utilisateurs indiqués à choisir un nouveau mot de passe.

set -o pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

if [ "$(id -u)" -ne 0 ]; then
    error 'Run this script with sudo to update user accounts.'
fi
if [ "$#" -eq 0 ]; then
    error "Usage: ${0##*/} username [username ...]"
fi

for command_name in chage getent grep id; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done

# Je vérifie tous les comptes avant de modifier le premier.
for user in "$@"; do
    if [[ ! "$user" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
        error "Invalid username: $user"
    fi
    if ! getent passwd "$user" | grep -q "^${user}:"; then
        error "User account not found: $user"
    fi
done

printf '=== Force Password Change ===\n\n'
printf 'Processing users with compromised passwords...\n\n'
changed_users=0

for user in "$@"; do
    printf '%s:\n' "$user"
    if ! chage -d 0 "$user"; then
        error "Could not expire the password for user: $user"
    fi

    aging_info=$(LC_ALL=C chage -l "$user") || \
        error "Could not verify password status for user: $user"
    if ! printf '%s\n' "$aging_info" | \
        grep -qi 'password must be changed'; then
        error "Password expiration was not confirmed for user: $user"
    fi

    expiry_line=$(printf '%s\n' "$aging_info" | \
        grep -E '^Password expires[[:space:]]*:')
    if [ -z "$expiry_line" ]; then
        error "Password expiration details are missing for user: $user"
    fi

    printf '  Password expired: FORCED\n'
    printf '  Must change at next login: YES\n\n'
    changed_users=$((changed_users + 1))
done

printf 'Verification:\n'
for user in "$@"; do
    printf '  chage -l %s | grep "Password expires"\n' "$user"
    LC_ALL=C chage -l "$user" | grep -E '^Password expires[[:space:]]*:'
done

printf '\n%s users must change password at next login.\n' "$changed_users"
