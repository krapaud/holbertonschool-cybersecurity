#!/bin/bash

# Je vérifie la politique MFA et teste les deux ordres de connexion en local.

set -o pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

for command_name in awk grep mktemp rm ssh sshd stat systemctl timeout; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done

if [ "$(id -u)" -eq 0 ]; then
    error 'Run this test as the regular user whose TOTP configuration is being checked.'
fi
if [ -z "${HOME:-}" ] || [ ! -d "$HOME" ]; then
    error 'The current user home directory is unavailable.'
fi

pam_file=/etc/pam.d/sshd
ssh_file=/etc/ssh/sshd_config
secret_file=$HOME/.google_authenticator
private_key=$HOME/.ssh/id_ed25519
[ -r "$pam_file" ] || error "Cannot read $pam_file."
[ -r "$ssh_file" ] || error "Cannot read $ssh_file."

temporary_directory=$(mktemp -d) || error 'Could not create a temporary directory.'
trap 'rm -rf -- "$temporary_directory"' EXIT
effective_config=$temporary_directory/sshd-effective
key_test_log=$temporary_directory/key-only.log
totp_test_log=$temporary_directory/totp-only.log

if ! sshd -T > "$effective_config" 2>/dev/null; then
    error 'Could not read the effective SSH daemon configuration.'
fi

get_setting()
{
    awk -v name="$1" '$1 == name { print $2; exit }' "$effective_config"
}

ssh_port=$(get_setting port)
ssh_port=${ssh_port:-22}
auth_methods=$(awk '$1 == "authenticationmethods" { $1 = ""; sub(/^[[:space:]]+/, ""); print; exit }' "$effective_config")
pubkey_auth=$(get_setting pubkeyauthentication)
kbd_auth=$(get_setting kbdinteractiveauthentication)
use_pam=$(get_setting usepam)

test_failures=0
mark_pass()
{
    printf '  Result: CORRECT ✓\n'
}
mark_fail()
{
    printf '  Result: FAILED - %s\n' "$1"
    test_failures=$((test_failures + 1))
}

printf '=== MFA Testing ===\n\n'
printf 'Testing authentication requirements...\n\n'

# Je ne saisis aucun code: le succès partiel de la clé prouve qu'un facteur reste.
printf 'Test 1: SSH with key only (no TOTP)\n'
printf '  Expected: Prompt for verification code\n'
ssh_active=0
if systemctl is-active --quiet ssh.service || \
    systemctl is-active --quiet sshd.service; then
    ssh_active=1
fi
if [ -r "$private_key" ] && [ "$ssh_active" -eq 1 ]; then
    timeout 8 ssh -i "$private_key" -vv -F /dev/null \
        -o BatchMode=yes \
        -o IdentitiesOnly=yes \
        -o PasswordAuthentication=no \
        -o KbdInteractiveAuthentication=yes \
        -o PreferredAuthentications=publickey,keyboard-interactive \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=5 \
        -p "$ssh_port" "$(id -un)@127.0.0.1" true \
        > "$key_test_log" 2>&1 || true
    if grep -Fq 'Authenticated using "publickey" with partial success' "$key_test_log" && \
        grep -Fq 'Next authentication method: keyboard-interactive' "$key_test_log"; then
        mark_pass
    else
        mark_fail 'The key was not confirmed as the first factor by the local SSH service.'
    fi
else
    mark_fail 'The SSH service or the current user private key is unavailable.'
fi

# Sans clé, AuthenticationMethods ne doit pas laisser démarrer keyboard-interactive.
printf '\nTest 2: SSH with TOTP only (no key)\n'
printf '  Expected: Connection refused\n'
timeout 8 ssh -vv -F /dev/null \
    -o BatchMode=yes \
    -o PubkeyAuthentication=no \
    -o KbdInteractiveAuthentication=yes \
    -o PasswordAuthentication=no \
    -o PreferredAuthentications=keyboard-interactive \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=5 \
    -p "$ssh_port" "$(id -un)@127.0.0.1" true \
    > "$totp_test_log" 2>&1 || true
if grep -Fq 'Authentications that can continue: publickey' "$totp_test_log" && \
    ! grep -Fq 'Authenticated using "keyboard-interactive"' "$totp_test_log"; then
    mark_pass
else
    mark_fail 'The server did not prove that a public key is required before TOTP.'
fi

printf '\nTest 3: PAM configuration check\n'
if grep -Eq '^[[:space:]]*auth[[:space:]]+required[[:space:]]+pam_google_authenticator\.so([[:space:]]|$)' "$pam_file"; then
    printf '  pam_google_authenticator.so: Present in %s ✓\n' "$pam_file"
else
    printf '  pam_google_authenticator.so: MISSING from %s\n' "$pam_file"
    test_failures=$((test_failures + 1))
fi

printf '\nTest 4: SSH configuration check\n'
if grep -Fq 'AuthenticationMethods publickey,keyboard-interactive' "$ssh_file" && \
    [ "$auth_methods" = 'publickey,keyboard-interactive' ]; then
    printf '  AuthenticationMethods: %s ✓\n' "$auth_methods"
else
    printf '  AuthenticationMethods: %s (expected publickey,keyboard-interactive)\n' "${auth_methods:-not set}"
    test_failures=$((test_failures + 1))
fi
if [ "$kbd_auth" = yes ] && [ "$pubkey_auth" = yes ] && [ "$use_pam" = yes ]; then
    printf '  ChallengeResponseAuthentication: yes ✓\n'
else
    printf '  ChallengeResponseAuthentication: FAILED (keyboard-interactive=%s, publickey=%s, UsePAM=%s)\n' \
        "${kbd_auth:-unset}" "${pubkey_auth:-unset}" "${use_pam:-unset}"
    test_failures=$((test_failures + 1))
fi

printf '\nTest 5: User TOTP configuration\n'
if [ -s "$secret_file" ]; then
    printf '  ~/.google_authenticator: Exists ✓\n'
else
    printf '  ~/.google_authenticator: MISSING\n'
    test_failures=$((test_failures + 1))
fi
secret_mode=$(stat -c '%a' "$secret_file" 2>/dev/null || printf missing)
secret_owner=$(stat -c '%u' "$secret_file" 2>/dev/null || printf missing)
if [ "$secret_mode" = 600 ] && [ "$secret_owner" = "$(id -u)" ]; then
    printf '  Permissions (600): Correct ✓\n'
else
    printf '  Permissions (600): INCORRECT (mode=%s owner=%s)\n' "$secret_mode" "$secret_owner"
    test_failures=$((test_failures + 1))
fi

if [ "$test_failures" -eq 0 ]; then
    printf '\nAll MFA tests: PASSED\n'
    printf 'Two-factor authentication is properly configured.\n'
else
    printf '\nAll MFA tests: FAILED (%s issue(s))\n' "$test_failures"
    exit 1
fi
