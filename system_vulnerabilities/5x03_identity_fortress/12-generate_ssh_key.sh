#!/bin/bash
# Je crée une clé ED25519 personnelle et protège le fichier privé.

set -o pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

for command_name in awk cat chmod hostname mkdir rm ssh-keygen; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done

if [ -z "${HOME:-}" ] || [ ! -d "$HOME" ] || [ ! -w "$HOME" ]; then
    error 'HOME is missing or not writable.'
fi

ssh_directory=$HOME/.ssh
private_key=$ssh_directory/id_ed25519
public_key=$private_key.pub
if [ -e "$private_key" ] || [ -e "$public_key" ]; then
    error "A key already exists at $private_key; move it first if you want a new pair."
fi

umask 077
if ! mkdir -p -- "$ssh_directory"; then
    error "Could not create $ssh_directory."
fi
if ! chmod 700 "$ssh_directory"; then
    error "Could not secure $ssh_directory."
fi

host_name=$(hostname -f 2>/dev/null || hostname)
key_comment="${USER:-user}@${host_name}"

printf '=== SSH Key Generation ===\n\n'
printf 'Generating ED25519 key pair...\n'
printf '  Algorithm: ED25519 (recommended)\n'
printf '  Key file: %s\n\n' "$private_key"
printf 'Enter passphrase (recommended):\n'
if ! ssh-keygen -t ed25519 -a 100 -C "$key_comment" \
    -f "$private_key"; then
    rm -f -- "$private_key" "$public_key"
    error 'SSH key generation failed.'
fi

if ! chmod 600 "$private_key" || ! chmod 644 "$public_key"; then
    error 'Could not set secure key permissions.'
fi

fingerprint=$(ssh-keygen -lf "$public_key" -E sha256 | awk '{ print $2 }') || \
    error 'Could not calculate the public key fingerprint.'

printf '\nKey pair generated:\n'
printf '  Private key: %s\n' "$private_key"
printf '  Public key: %s\n' "$public_key"
printf '\nSetting permissions...\n'
printf '  Private key: 600 (owner read/write only)\n'
printf '  Public key: 644\n'
printf '\nPublic key fingerprint:\n'
printf '  %s\n' "$fingerprint"
printf '\nYour public key:\n'
cat "$public_key"
printf '\nNext step: Add this public key to target servers\047 authorized_keys.\n'
