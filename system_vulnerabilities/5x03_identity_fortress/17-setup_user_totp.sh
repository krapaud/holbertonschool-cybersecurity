#!/bin/bash

# Je crée le secret TOTP du compte courant avec les réglages demandés.

set -o pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

for command_name in chmod google-authenticator stat; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done

if [ "$(id -u)" -eq 0 ]; then
    error 'Run this script as the user who will use the TOTP secret, not as root.'
fi

if [ -z "${HOME:-}" ] || [ ! -d "$HOME" ] || [ ! -w "$HOME" ]; then
    error 'The current user home directory is missing or not writable.'
fi

secret_file=$HOME/.google_authenticator
if [ -e "$secret_file" ]; then
    error "$secret_file already exists. Keep the current factor or back it up before replacing it."
fi

# Je limite les permissions pendant la création du secret et des codes de secours.
umask 077

printf '=== TOTP Setup for Current User ===\n\n'
printf 'Running google-authenticator with secure defaults...\n\n'

if ! google-authenticator \
    -t \
    -d \
    -r 3 \
    -R 30 \
    -w 3 \
    -e 5 \
    -f; then
    error 'Google Authenticator setup failed. Check the command output before retrying.'
fi

if [ ! -f "$secret_file" ]; then
    error "The setup command completed, but $secret_file was not created."
fi

if ! chmod 600 "$secret_file"; then
    error "Could not set secure permissions on $secret_file."
fi

file_mode=$(stat -c '%a' "$secret_file") || \
    error "Could not verify permissions on $secret_file."
if [ "$file_mode" != 600 ]; then
    error "Unexpected permissions on $secret_file: $file_mode"
fi

printf '\nConfiguration saved to %s\n' "$secret_file"
printf '\nSettings applied:\n'
printf ' Time-based tokens: YES\n'
printf ' Rate limiting: 3 logins per 30 seconds\n'
printf ' Token reuse: DISALLOWED\n'
printf ' Window size: 3 (allows clock skew)\n'
printf '\nIMPORTANT: Save your emergency codes securely!\n'
printf 'Scan the QR code with your authenticator app.\n'
