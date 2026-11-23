#!/bin/bash
# Je règle les durées de validité et les applique aux comptes interactifs.

set -o pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

if [ "$(id -u)" -ne 0 ]; then
    error 'Run this script with sudo to configure password aging.'
fi

for command_name in awk chage cp getent id install mktemp rm stat; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done

login_file=/etc/login.defs
backup_file=/etc/login.defs.bak
if [ ! -r "$login_file" ]; then
    error "Login defaults file is missing or unreadable: $login_file"
fi

# Je lis les valeurs actuelles pour afficher les changements appliqués.
get_setting()
{
    local setting_name=$1
    local default_value=$2

    awk -v key="$setting_name" -v fallback="$default_value" \
        '$1 == key && $1 !~ /^#/ { value = $2 }
        END { if (value != "") print value; else print fallback }' \
        "$login_file"
}

old_max=$(get_setting PASS_MAX_DAYS 99999)
old_min=$(get_setting PASS_MIN_DAYS 0)
old_warn=$(get_setting PASS_WARN_AGE 7)

printf '=== Password Aging Configuration ===\n\n'

# Je sauvegarde le fichier original une seule fois avant de le réécrire.
if [ ! -e "$backup_file" ] && ! cp /etc/login.defs /etc/login.defs.bak; then
    error "Could not create backup: $backup_file"
fi

temporary_directory=$(mktemp -d) || \
    error 'Could not create a temporary directory.'
trap 'rm -rf -- "$temporary_directory"' EXIT
new_login_file=$temporary_directory/login.defs

if ! awk '
    BEGIN {
        managed["PASS_MAX_DAYS"] = 1
        managed["PASS_MIN_DAYS"] = 1
        managed["PASS_WARN_AGE"] = 1
    }
    $1 in managed { next }
    { print }
' "$login_file" > "$new_login_file"; then
    error 'Could not prepare login.defs.'
fi
cat >> "$new_login_file" <<'EOF'
PASS_MAX_DAYS   90
PASS_MIN_DAYS   1
PASS_WARN_AGE   14
EOF

file_owner=$(stat -c '%U' "$login_file") || file_owner=root
file_group=$(stat -c '%G' "$login_file") || file_group=root
file_mode=$(stat -c '%a' "$login_file") || file_mode=0644

printf 'Configuring %s...\n' "$login_file"
if ! install -o "$file_owner" -g "$file_group" -m "$file_mode" \
    "$new_login_file" "$login_file"; then
    cp -a -- "$backup_file" "$login_file" 2>/dev/null || true
    error "Could not update $login_file"
fi
printf '  PASS_MAX_DAYS: %s -> 90\n' "$old_max"
printf '  PASS_MIN_DAYS: %s -> 1\n' "$old_min"
printf '  PASS_WARN_AGE: %s -> 14\n' "$old_warn"

printf '\nNote: These settings apply to NEW accounts only.\n'
printf 'Existing accounts must be updated with chage.\n\n'
printf 'Applying to existing users...\n'
mapfile -t interactive_users < <(getent passwd | awk -F: \
    '$3 >= 1000 && $7 != "" && $7 !~ /(nologin|false)$/ { print $1 }')

if [ "${#interactive_users[@]}" -eq 0 ]; then
    printf '  No interactive user accounts found.\n'
fi

for user in "${interactive_users[@]}"; do
    if [[ ! "$user" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
        error "Invalid account name returned by getent: $user"
    fi

    # Les noms validés ci-dessus ne contiennent ni espace ni joker shell.
    # shellcheck disable=SC2086
    if ! chage -M 90 $user || \
        ! chage -m 1 $user || \
        ! chage -W 14 $user; then
        error "Could not apply password aging to user: $user"
    fi

    aging_info=$(LC_ALL=C chage -l "$user") || \
        error "Could not verify password aging for user: $user"
    max_days=$(printf '%s\n' "$aging_info" | awk -F': ' '
        {
            label = $1
            sub(/[[:space:]]+$/, "", label)
            if (label == "Maximum number of days between password change") {
                print $2
            }
        }
    ')
    min_days=$(printf '%s\n' "$aging_info" | awk -F': ' '
        {
            label = $1
            sub(/[[:space:]]+$/, "", label)
            if (label == "Minimum number of days between password change") {
                print $2
            }
        }
    ')
    warn_days=$(printf '%s\n' "$aging_info" | awk -F': ' '
        {
            label = $1
            sub(/[[:space:]]+$/, "", label)
            if (label == "Number of days of warning before password expires") {
                print $2
            }
        }
    ')

    if [ "$max_days" != 90 ] || [ "$min_days" != 1 ] || \
        [ "$warn_days" != 14 ]; then
        error "Password aging verification failed for user: $user"
    fi
    printf '  %s: Max=%s, Min=%s, Warn=%s\n' \
        "$user" "$max_days" "$min_days" "$warn_days"
done

printf '  [Skipping system accounts]\n'
printf '\nPassword aging: CONFIGURED\n'
