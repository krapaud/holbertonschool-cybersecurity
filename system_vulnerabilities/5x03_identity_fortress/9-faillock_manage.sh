#!/bin/bash
# Je consulte et réinitialise les compteurs faillock des comptes Linux.

set -o pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

usage()
{
    printf 'Usage: %s status | show USER | reset USER\n' "${0##*/}" >&2
    exit 2
}

if [ "$(id -u)" -ne 0 ]; then
    error 'Run this script with sudo to manage faillock records.'
fi

for command_name in awk date faillock getent grep mktemp rm sort; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done

read_setting()
{
    local setting_name=$1
    local default_value=$2
    local value

    value=$(awk -v key="$setting_name" \
        '$1 == key && $2 == "=" { value = $3 }
        END { if (value != "") print value }' \
        /etc/security/faillock.conf 2>/dev/null)
    printf '%s' "${value:-$default_value}"
}

deny=$(read_setting deny 3)
unlock_time=$(read_setting unlock_time 600)
fail_interval=$(read_setting fail_interval 900)
[[ "$deny" =~ ^[0-9]+$ ]] || error 'Invalid deny value in faillock.conf.'
[[ "$unlock_time" =~ ^[0-9]+$ ]] || \
    error 'Invalid unlock_time value in faillock.conf.'
[[ "$fail_interval" =~ ^[0-9]+$ ]] || \
    error 'Invalid fail_interval value in faillock.conf.'

temporary_directory=$(mktemp -d) || \
    error 'Could not create a temporary directory.'
trap 'rm -rf -- "$temporary_directory"' EXIT
all_records=$temporary_directory/all-records
user_records=$temporary_directory/user-records
recent_records=$temporary_directory/recent-records

validate_user()
{
    local username=$1

    [[ "$username" =~ ^[a-zA-Z0-9_.-]+$ ]] || \
        error "Invalid username: $username"
    if ! getent passwd "$username" | grep -q "^${username}:"; then
        error "User account not found: $username"
    fi
}

# Je transforme l’affichage faillock en lignes faciles à traiter.
load_user_records()
{
    local username=$1

    if ! faillock --user "$username" > "$user_records"; then
        error "Could not read faillock records for $username."
    fi
    if ! awk '
        $1 ~ /^[0-9][0-9][0-9][0-9]-/ && $2 ~ /^[0-9][0-9]:/ {
            print $1, $2, $3, $4, $NF
        }
    ' "$user_records" > "$recent_records"; then
        error "Could not parse faillock records for $username."
    fi
}

# Je calcule le nombre d’échecs dans la fenêtre, puis l’heure de déblocage.
get_user_lock_state()
{
    local record_date record_time record_type source valid
    local record_epoch now_epoch

    failure_count=0
    last_failure_epoch=0
    now_epoch=$(date +%s) || error 'Could not read the system clock.'
    while read -r record_date record_time record_type source valid; do
        [ "$valid" = V ] || continue
        record_epoch=$(date -d "$record_date $record_time" +%s 2>/dev/null) || \
            continue
        if (( now_epoch - record_epoch <= fail_interval &&
            now_epoch >= record_epoch )); then
            failure_count=$((failure_count + 1))
            if (( record_epoch > last_failure_epoch )); then
                last_failure_epoch=$record_epoch
            fi
        fi
    done < "$recent_records"

    unlock_epoch=0
    if (( failure_count >= deny && last_failure_epoch > 0 )); then
        unlock_epoch=$((last_failure_epoch + unlock_time))
    fi
    if (( now_epoch >= unlock_epoch )); then
        unlock_epoch=0
    fi
}

show_user_status()
{
    local username=$1
    local record_date record_time record_type source valid
    local record_epoch now_epoch

    validate_user "$username"
    load_user_records "$username"
    get_user_lock_state

    printf '=== Faillock Details: %s ===\n\n' "$username"
    printf 'Recent failures:\n'
    now_epoch=$(date +%s) || error 'Could not read the system clock.'
    while read -r record_date record_time record_type source valid; do
        [ "$valid" = V ] || continue
        record_epoch=$(date -d "$record_date $record_time" +%s 2>/dev/null) || \
            continue
        if (( now_epoch - record_epoch <= fail_interval &&
            now_epoch >= record_epoch )); then
            printf '  %s %s - Failed auth from %s\n' \
                "$record_date" "$record_time" "$source"
        fi
    done < "$recent_records"

    if (( unlock_epoch > 0 )); then
        printf '\nStatus: LOCKED\n'
        printf 'Unlocks automatically at: %s\n' \
            "$(date -d "@$unlock_epoch" '+%H:%M:%S')"
    else
        printf '\nStatus: NOT LOCKED\n'
    fi
}

show_all_locked()
{
    local username
    local found=0

    if ! faillock > "$all_records"; then
        error 'Could not read faillock records.'
    fi

    printf '=== Faillock Status ===\n\n'
    printf 'Locked accounts:\n'
    while IFS= read -r username; do
        [ -n "$username" ] || continue
        load_user_records "$username"
        get_user_lock_state
        if (( unlock_epoch > 0 )); then
            found=1
            printf '  %s: %s failures (locked until %s)\n' \
                "$username" "$failure_count" \
                "$(date -d "@$unlock_epoch" '+%H:%M:%S')"
        fi
    done < <(awk '/^[^[:space:]][^:]*:$/ { sub(/:$/, ""); print }' \
        "$all_records" | sort -u)

    if [ "$found" -eq 0 ]; then
        printf '  None\n'
    fi
}

if [ "$#" -lt 1 ]; then
    usage
fi

case "$1" in
    status)
        [ "$#" -eq 1 ] || usage
        show_all_locked
        ;;
    show)
        [ "$#" -eq 2 ] || usage
        show_user_status "$2"
        ;;
    reset)
        [ "$#" -eq 2 ] || usage
        validate_user "$2"
        if ! faillock --user "$2" --reset; then
            error "Could not clear faillock records for $2."
        fi
        printf 'Account %s: Lock cleared\n' "$2"
        ;;
    *)
        usage
        ;;
esac
