#!/bin/bash
# Je consulte les jails Fail2ban et je peux retirer une IP bannie.

set -o pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

usage()
{
    printf 'Usage: %s status | banned | unban IP\n' "${0##*/}" >&2
    exit 2
}

if [ "$(id -u)" -ne 0 ]; then
    error 'Run this script with sudo to manage Fail2ban jails.'
fi

for command_name in awk fail2ban-client systemctl; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done

get_jails()
{
    local status_output

    status_output=$(fail2ban-client status) || \
        error 'Could not read Fail2ban status.'
    printf '%s\n' "$status_output" | awk -F: \
        '/Jail list:/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); \
        n = split($2, names, /,[[:space:]]*/); \
        for (i = 1; i <= n; i++) if (names[i] != "") print names[i] }'
}

get_jail_status()
{
    local jail_name=$1

    fail2ban-client status "$jail_name" || \
        error "Could not read status for jail $jail_name."
}

show_status()
{
    local jail_name jail_output
    local -a jails

    printf '=== fail2ban Status ===\n\n'
    if systemctl is-active --quiet fail2ban.service; then
        printf 'Service: Active\n'
    else
        error 'fail2ban.service is not active.'
    fi

    mapfile -t jails < <(get_jails)
    printf 'Jails: %s\n' "${jails[*]:-None}"
    for jail_name in "${jails[@]}"; do
        jail_output=$(get_jail_status "$jail_name")
        printf '\n[%s] Statistics:\n' "$jail_name"
        printf '%s\n' "$jail_output" | awk -F: '
            /Currently banned:/ { print "  Currently banned: " $2 }
            /Total banned:/ { print "  Total banned: " $2 }
            /Currently failed:/ { print "  Currently failed: " $2 }
        '
    done
}

show_banned()
{
    local jail_name jail_output banned_list ip_address
    local -a jails banned_ips

    printf '=== Banned IPs ===\n\n'
    mapfile -t jails < <(get_jails)
    for jail_name in "${jails[@]}"; do
        jail_output=$(get_jail_status "$jail_name")
        banned_list=$(printf '%s\n' "$jail_output" | awk -F: \
            '/Banned IP list:/ { sub(/^[[:space:]]+/, "", $2); print $2 }')
        printf 'Jail: %s\n' "$jail_name"
        if [ -z "$banned_list" ]; then
            printf '  None\n'
            continue
        fi
        IFS=',' read -r -a banned_ips <<< "$banned_list"
        for ip_address in "${banned_ips[@]}"; do
            ip_address=${ip_address//[[:space:]]/}
            [ -n "$ip_address" ] && printf '  %s\n' "$ip_address"
        done
    done
    if [ "${#jails[@]}" -eq 0 ]; then
        printf 'No active jails.\n'
    fi
}

unban_ip()
{
    local ip_address=$1

    [[ "$ip_address" =~ ^[0-9a-fA-F:.]+$ ]] || \
        error "Invalid IP address: $ip_address"
    if ! fail2ban-client status sshd >/dev/null 2>&1; then
        error 'The sshd jail is not active.'
    fi
    fail2ban-client set sshd unbanip "$ip_address" >/dev/null || \
        error "Could not unban $ip_address from jail sshd."
    printf 'IP %s unbanned from jail sshd\n' "$ip_address"
}

if [ "$#" -lt 1 ]; then
    usage
fi

if [ "$1" = "status" ]; then
    [ "$#" -eq 1 ] || usage
    show_status
elif [ "$1" = "banned" ]; then
    [ "$#" -eq 1 ] || usage
    show_banned
elif [ "$1" = "unban" ]; then
    [ "$#" -eq 2 ] || usage
    unban_ip "$2"
else
    usage
fi
