#!/bin/bash
# Je repère les outils de développement et d’administration installés.

set -o pipefail

if ! command -v dpkg-query >/dev/null 2>&1; then
    printf '[ERROR] dpkg-query est introuvable sur ce système.\n' >&2
    exit 1
fi

is_package_installed()
{
    local package_name=$1
    local package_status

    package_status=$(dpkg-query -W -f='${db:Status-Status}' \
        "$package_name" 2>/dev/null) || return 1
    [ "$package_status" = installed ]
}

audit_group()
{
    local package_entry
    local package_name
    local description
    local count=0

    for package_entry in "$@"; do
        IFS='|' read -r package_name description <<< "$package_entry"
        if is_package_installed "$package_name"; then
            printf '  [FOUND] %s (%s)\n' "$package_name" "$description"
            count=$((count + 1))
        fi
    done
    if [ "$count" -eq 0 ]; then
        printf '  None found\n'
    fi
    GROUP_COUNT=$count
}

printf '=== Package Security Audit ===\n\n'
printf 'Checking for development tools...\n'
audit_group \
    'gcc|GNU C Compiler' \
    'g++|GNU C++ Compiler' \
    'make|Build automation' \
    'gdb|Debugger'
development_count=$GROUP_COUNT
printf '\n'

printf 'Checking for network tools...\n'
audit_group \
    'netcat-openbsd|Network Swiss Army Knife' \
    'nmap|Network scanner' \
    'tcpdump|Packet capture'
network_count=$GROUP_COUNT
printf '\n'

printf 'Checking for remote access tools...\n'
audit_group 'telnet|Insecure remote access'
remote_count=$GROUP_COUNT
printf '\n'

printf 'Summary:\n'
printf '  Development tools: %s found\n' "$development_count"
printf '  Network tools: %s found\n' "$network_count"
printf '  Remote access: %s found\n\n' "$remote_count"

printf 'Recommendation: Review and remove unnecessary packages.\n'
