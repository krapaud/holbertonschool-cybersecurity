#!/bin/bash

# J'audite les politiques d'identité et les comptes sans afficher de secrets.

set -o pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

if [ "$(id -u)" -ne 0 ]; then
    error 'Run this audit with sudo so account and service settings can be checked.'
fi

for command_name in awk chage date getent grep \
    mktemp rm sshd stat systemctl; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done

temporary_directory=$(mktemp -d) || \
    error 'Could not create a temporary directory.'
trap 'rm -rf -- "$temporary_directory"' EXIT
effective_ssh=$temporary_directory/sshd-effective
interactive_users=$temporary_directory/interactive-users

pam_quality=/etc/pam.d/common-password
pam_sshd=/etc/pam.d/sshd
ssh_config_file=/etc/ssh/sshd_config
quality_config=/etc/security/pwquality.conf
history_file=/etc/security/opasswd
aging_config=/etc/login.defs
faillock_config=/etc/security/faillock.conf

# Je lis les valeurs actives des fichiers de configuration sans les modifier.
read_equals_setting()
{
    local file_path=$1
    local setting_name=$2
    awk -v key="$setting_name" \
        '$1 == key && $2 == "=" { value = $3 }
        END { if (value != "") print value }' "$file_path" 2>/dev/null
}

read_plain_setting()
{
    local file_path=$1
    local setting_name=$2
    awk -v key="$setting_name" \
        '$1 == key && $1 !~ /^#/ { value = $2 }
        END { if (value != "") print value }' "$file_path" 2>/dev/null
}

check_total=0
check_passed=0
check_result()
{
    local description=$1
    local is_ok=$2
    check_total=$((check_total + 1))
    if [ "$is_ok" -eq 1 ]; then
        printf '  [PASS] %s\n' "$description"
        check_passed=$((check_passed + 1))
    else
        printf '  [FAIL] %s\n' "$description"
    fi
}

quality_rule=0
if [ -r "$pam_quality" ] && \
    grep -Eq '^[[:space:]]*password[[:space:]]+[^#].*pam_pwquality[.]so' "$pam_quality"; then
    quality_rule=1
fi
minimum_length=$(read_equals_setting "$quality_config" minlen)
history_rule=0
if [ -r "$pam_quality" ] && \
    grep -Eq '^[[:space:]]*password[[:space:]]+[^#].*pam_pwhistory[.]so.*remember=5.*use_authtok' "$pam_quality"; then
    history_rule=1
fi
history_mode=$(stat -c '%a' "$history_file" 2>/dev/null || printf missing)
history_owner=$(stat -c '%u' "$history_file" 2>/dev/null || printf missing)

aging_max=$(read_plain_setting "$aging_config" PASS_MAX_DAYS)
deny=$(read_equals_setting "$faillock_config" deny)
unlock_time=$(read_equals_setting "$faillock_config" unlock_time)
fail_interval=$(read_equals_setting "$faillock_config" fail_interval)
faillock_active=0
if grep -RqsE '^[[:space:]]*[^#].*pam_faillock[.]so' /etc/pam.d 2>/dev/null; then
    faillock_active=1
fi

if ! sshd -T > "$effective_ssh" 2>/dev/null; then
    : > "$effective_ssh"
fi
ssh_setting()
{
    awk -v key="$1" '$1 == key { print $2; exit }' "$effective_ssh"
}
ssh_password=$(ssh_setting passwordauthentication)
ssh_pubkey=$(ssh_setting pubkeyauthentication)
ssh_pam=$(ssh_setting usepam)
ssh_interactive=$(ssh_setting kbdinteractiveauthentication)
ssh_methods=$(awk '$1 == "authenticationmethods" { $1 = ""; sub(/^[[:space:]]+/, ""); print; exit }' "$effective_ssh")
expected_password_setting='PasswordAuthentication no'
password_auth_disabled=0
if grep -Fq "$expected_password_setting" "$ssh_config_file" && \
    [ "$ssh_password" = no ]; then
    password_auth_disabled=1
fi
totp_pam_rule=0
if [ -r "$pam_sshd" ] && \
    grep -Eq '^[[:space:]]*auth[[:space:]]+required[[:space:]]+pam_google_authenticator[.]so' "$pam_sshd"; then
    totp_pam_rule=1
fi

# Je ne compte que les comptes humains avec un répertoire et un shell de connexion.
getent passwd | awk -F: \
    '$3 >= 1000 && $6 != "" && $7 !~ /(nologin|false)$/ { print $0 }' \
    > "$interactive_users" || error 'Could not enumerate local and directory-service accounts.'

missing_totp=0
expired_accounts=0
bad_aging_accounts=0
while IFS=: read -r username _ uid _ _ home shell_path; do
    [[ "$uid" =~ ^[0-9]+$ ]] || continue
    [ -d "$home" ] || continue

    totp_file=$home/.google_authenticator
    totp_mode=$(stat -c '%a' "$totp_file" 2>/dev/null || printf missing)
    totp_owner=$(stat -c '%u' "$totp_file" 2>/dev/null || printf missing)
    if [ ! -s "$totp_file" ] || [ "$totp_mode" != 600 ] || [ "$totp_owner" != "$uid" ]; then
        missing_totp=$((missing_totp + 1))
    fi

    account_aging=$(LC_ALL=C chage -l "$username" 2>/dev/null) || account_aging=
    account_max=$(printf '%s\n' "$account_aging" | awk -F: '
        $1 ~ /^Maximum number of days between password change[[:space:]]*$/ {
            gsub(/^[[:space:]]+/, "", $2); print $2; exit
        }')
    [ "$account_max" = 90 ] || bad_aging_accounts=$((bad_aging_accounts + 1))

    expires=$(printf '%s\n' "$account_aging" | awk -F: '
        $1 ~ /^Password expires[[:space:]]*$/ {
            gsub(/^[[:space:]]+/, "", $2); print $2; exit
        }')
    case "$expires" in
        never|"" )
            ;;
        *"must be changed"*)
            expired_accounts=$((expired_accounts + 1))
            ;;
        *)
            expiry_epoch=$(date -d "$expires" +%s 2>/dev/null) || expiry_epoch=
            if [ -z "$expiry_epoch" ] || (( expiry_epoch < $(date +%s) )); then
                expired_accounts=$((expired_accounts + 1))
            fi
            ;;
    esac
done < "$interactive_users"

fail2ban_active=0
if command -v fail2ban-client >/dev/null 2>&1 && \
    systemctl is-active --quiet fail2ban.service && \
    fail2ban-client status sshd >/dev/null 2>&1; then
    fail2ban_active=1
fi

printf '=== Identity Security Audit ===\n\n'
printf 'Password Policy:\n'
if [ "$quality_rule" -eq 1 ]; then
    printf '  Complexity enforcement: ACTIVE\n'
else
    printf '  Complexity enforcement: INACTIVE\n'
fi
if [ "$minimum_length" = 12 ]; then
    printf '  Minimum length 12: CONFIGURED\n'
else
    printf '  Minimum length 12: NOT CONFIGURED\n'
fi
if [ "$history_rule" -eq 1 ]; then
    printf '  History (5 passwords): CONFIGURED\n'
else
    printf '  History (5 passwords): NOT CONFIGURED\n'
fi
if [ "$aging_max" = 90 ] && [ "$bad_aging_accounts" -eq 0 ]; then
    printf '  Aging (90 days max): CONFIGURED\n'
else
    printf '  Aging (90 days max): NOT CONFIGURED\n'
fi

printf '\nAccount Protection:\n'
if [ "$faillock_active" -eq 1 ]; then
    printf '  pam_faillock: ACTIVE\n'
else
    printf '  pam_faillock: INACTIVE\n'
fi
if [ "$deny" = 5 ] && [ "$unlock_time" = 900 ] && [ "$fail_interval" = 900 ]; then
    printf '  Lockout after 5 attempts: CONFIGURED\n'
else
    printf '  Lockout after 5 attempts: NOT CONFIGURED\n'
fi
if [ "$fail2ban_active" -eq 1 ]; then
    printf '  fail2ban for SSH: ACTIVE\n'
else
    printf '  fail2ban for SSH: INACTIVE\n'
fi

printf '\nSSH Security:\n'
if [ "$password_auth_disabled" -eq 1 ]; then
    printf '  Password authentication: DISABLED\n'
else
    printf '  Password authentication: ENABLED OR UNKNOWN\n'
fi
if [ "$ssh_pubkey" = yes ]; then
    printf '  Public key authentication: ENABLED\n'
else
    printf '  Public key authentication: DISABLED OR UNKNOWN\n'
fi
if [ "$ssh_methods" = 'publickey,keyboard-interactive' ] && \
    [ "$ssh_interactive" = yes ] && [ "$ssh_pam" = yes ] && [ "$totp_pam_rule" -eq 1 ]; then
    printf '  MFA required: ENABLED\n'
    mfa_active=1
else
    printf '  MFA required: NOT CONFIGURED\n'
    mfa_active=0
fi

printf '\nUser Compliance:\n'
printf '  Users with weak passwords: NOT AUDITABLE (this audit does not inspect password values)\n'
printf '  Users without TOTP: %s (service accounts excluded)\n' "$missing_totp"
printf '  Accounts past password age: %s\n' "$expired_accounts"

check_result 'Password complexity policy active' "$quality_rule"
if [ "$minimum_length" = 12 ]; then check_result 'Minimum password length is 12' 1; else check_result 'Minimum password length is 12' 0; fi
if [ "$history_rule" -eq 1 ] && [ "$history_mode" = 600 ] && [ "$history_owner" = 0 ]; then
    check_result 'Password history retains five passwords' 1
else
    check_result 'Password history retains five passwords' 0
fi
if [ "$aging_max" = 90 ] && [ "$bad_aging_accounts" -eq 0 ]; then check_result 'Password aging is configured for 90 days' 1; else check_result 'Password aging is configured for 90 days' 0; fi
check_result 'PAM account lockout is active' "$faillock_active"
if [ "$deny" = 5 ] && [ "$unlock_time" = 900 ] && [ "$fail_interval" = 900 ]; then check_result 'Lockout threshold and duration are configured' 1; else check_result 'Lockout threshold and duration are configured' 0; fi
check_result 'Fail2ban SSH jail is active' "$fail2ban_active"
check_result 'SSH password authentication is disabled' "$password_auth_disabled"
if [ "$ssh_pubkey" = yes ]; then check_result 'SSH public-key authentication is enabled' 1; else check_result 'SSH public-key authentication is enabled' 0; fi
check_result 'SSH requires public key and TOTP' "$mfa_active"
if [ "$missing_totp" -eq 0 ]; then check_result 'All interactive users have protected TOTP files' 1; else check_result 'All interactive users have protected TOTP files' 0; fi
if [ "$expired_accounts" -eq 0 ]; then check_result 'No interactive accounts are past password age' 1; else check_result 'No interactive accounts are past password age' 0; fi

printf '\nSummary:\n'
printf '  Identity controls: %s/%s PASSED\n' "$check_passed" "$check_total"
if [ "$check_passed" -eq "$check_total" ]; then
    printf '  Compliance level: STRONG (configuration checks passed)\n'
    printf '\nSystem controls are configured. Weak-password status was not assessed.\n'
else
    printf '  Compliance level: NEEDS REVIEW\n'
    printf '\nResolve failed checks before production deployment.\n'
    exit 1
fi
