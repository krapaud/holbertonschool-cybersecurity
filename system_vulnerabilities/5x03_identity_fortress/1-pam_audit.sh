#!/bin/bash
# Je vérifie les réglages PAM et SSH sans modifier la configuration.

set -o pipefail

pam_directory=/etc/pam.d
auth_file=$pam_directory/common-auth
password_file=$pam_directory/common-password
sshd_pam_file=$pam_directory/sshd
ssh_config_file=/etc/ssh/sshd_config
login_defaults=/etc/login.defs

# Je regarde si un module existe dans le fichier indiqué.
has_module()
{
    local module_name=$1
    local file_path=$2

    [ -r "$file_path" ] || return 1
    grep -Eq "^[[:space:]]*[^#].*${module_name}([.]so)?([[:space:]]|$)" \
        "$file_path"
}

# Je récupère la valeur configurée dans login.defs ou j'affiche une valeur
# lisible si le paramètre n'est pas présent.
get_login_default()
{
    local setting_name=$1
    local default_value=$2
    local setting_value

    setting_value=$(awk -v key="$setting_name" \
        '$1 == key && $1 !~ /^#/ { value = $2 } END { print value }' \
        "$login_defaults" 2>/dev/null)
    printf '%s' "${setting_value:-$default_value}"
}

# Je lis les options SSH avec sshd -T quand c'est possible.
get_ssh_setting()
{
    local setting_name=$1
    local fallback_value=$2
    local setting_value

    if command -v sshd >/dev/null 2>&1; then
        setting_value=$(sshd -T 2>/dev/null | \
            awk -v key="$setting_name" '$1 == key { print $2; exit }')
    fi

    if [ -z "$setting_value" ] && [ -r "$ssh_config_file" ]; then
        setting_value=$(awk -v key="$setting_name" '
            tolower($1) == tolower(key) && $1 !~ /^#/ { value = $2 }
            END { print value }
        ' "$ssh_config_file")
    fi

    printf '%s' "${setting_value:-$fallback_value}"
}

printf '=== PAM Configuration Audit ===\n\n'

printf '%s:\n' "$auth_file"
if has_module pam_unix "$auth_file"; then
    printf '  pam_unix.so: Standard password authentication\n'
else
    printf '  pam_unix.so: NOT CONFIGURED\n'
fi
if has_module pam_deny "$auth_file"; then
    printf '  pam_deny.so: Fallback deny\n'
else
    printf '  pam_deny.so: NOT CONFIGURED\n'
fi

printf '\n%s:\n' "$password_file"
if has_module pam_unix "$password_file"; then
    printf '  pam_unix.so: Password change handling\n'
else
    printf '  pam_unix.so: NOT CONFIGURED\n'
fi
if has_module pam_pwquality "$password_file" || \
    has_module pam_cracklib "$password_file"; then
    printf '  Complexity enforcement: CONFIGURED\n'
else
    printf '  Complexity enforcement: NONE\n'
fi
if has_module pam_pwhistory "$password_file" || \
    has_module pam_unix "$password_file" && \
    grep -Eq 'remember=[0-9]+' "$password_file"; then
    printf '  History enforcement: CONFIGURED\n'
else
    printf '  History enforcement: NONE\n'
fi

printf '\n%s:\n' "$sshd_pam_file"
if [ -r "$sshd_pam_file" ] && \
    grep -Eq '^[[:space:]]*@include[[:space:]]+common-auth' \
        "$sshd_pam_file"; then
    printf '  @include common-auth\n'
else
    printf '  common-auth: NOT INCLUDED\n'
fi
if has_module pam_google_authenticator "$sshd_pam_file" || \
    has_module pam_oath "$sshd_pam_file" || \
    has_module pam_duo "$sshd_pam_file"; then
    printf '  MFA modules: CONFIGURED\n'
else
    printf '  MFA modules: NONE\n'
fi

printf '\nAccount Lockout:\n'
if grep -RqsE '^[[:space:]]*[^#].*pam_faillock([.]so)?([[:space:]]|$)' \
    "$pam_directory" 2>/dev/null; then
    printf '  pam_faillock: CONFIGURED\n'
else
    printf '  pam_faillock: NOT CONFIGURED\n'
fi
if grep -RqsE '^[[:space:]]*[^#].*pam_tally2([.]so)?([[:space:]]|$)' \
    "$pam_directory" 2>/dev/null; then
    printf '  pam_tally2: CONFIGURED\n'
else
    printf '  pam_tally2: NOT CONFIGURED\n'
fi

printf '\nPassword Aging:\n'
printf '  Default max days: %s\n' \
    "$(get_login_default PASS_MAX_DAYS 99999)"
printf '  Default min days: %s\n' \
    "$(get_login_default PASS_MIN_DAYS 0)"
printf '  Default warn days: %s\n' \
    "$(get_login_default PASS_WARN_AGE 7)"

printf '\nSSH Authentication:\n'
password_auth=$(get_ssh_setting passwordauthentication yes)
public_key_auth=$(get_ssh_setting pubkeyauthentication yes)
keyboard_auth=$(get_ssh_setting kbdinteractiveauthentication '')
if [ -z "$keyboard_auth" ]; then
    keyboard_auth=$(get_ssh_setting challengeresponseauthentication no)
fi

if [ "$password_auth" = yes ]; then
    printf '  PasswordAuthentication: yes (INSECURE)\n'
else
    printf '  PasswordAuthentication: %s\n' "$password_auth"
fi
printf '  PubkeyAuthentication: %s\n' "$public_key_auth"
printf '  ChallengeResponseAuthentication: %s\n' "$keyboard_auth"

if [ "$password_auth" = yes ] || \
    ! has_module pam_pwquality "$password_file" || \
    ! has_module pam_pwhistory "$password_file" || \
    ! grep -RqsE '^[[:space:]]*[^#].*pam_faillock([.]so)?([[:space:]]|$)' \
        "$pam_directory" 2>/dev/null || \
    ! has_module pam_google_authenticator "$sshd_pam_file"; then
    printf '\nSummary: Identity controls are WEAK\n'
else
    printf '\nSummary: Identity controls are ENABLED\n'
fi
