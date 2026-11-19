#!/bin/bash
# J’inventorie quelques binaires légitimes qui peuvent être détournés.

set -o pipefail

for command_name in readlink stat; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise introuvable: %s\n' \
            "$command_name" >&2
        exit 1
    fi
done

audit_group()
{
    local group_title=$1
    shift
    local entry
    local binary_name
    local warning
    local binary_path
    local resolved_path
    local permissions
    local mode
    local owner
    local group

    printf '%s\n' "$group_title"
    for entry in "$@"; do
        IFS='|' read -r binary_name warning <<< "$entry"
        binary_path=$(command -v "$binary_name" 2>/dev/null) || {
            printf '  %s: Not found\n' "$binary_name"
            continue
        }
        resolved_path=$(readlink -f -- "$binary_path" 2>/dev/null) || {
            printf '  %s: Unable to resolve path\n' "$binary_path"
            continue
        }
        if [ ! -f "$resolved_path" ] || [ ! -x "$resolved_path" ]; then
            printf '  %s: Not an executable file\n' "$resolved_path"
            continue
        fi

        permissions=$(stat -Lc '%A' "$resolved_path" 2>/dev/null) || {
            printf '  %s: Unable to read permissions\n' "$resolved_path"
            continue
        }
        mode=$(stat -Lc '%a' "$resolved_path" 2>/dev/null) || mode=unknown
        owner=$(stat -Lc '%U' "$resolved_path" 2>/dev/null) || owner=unknown
        group=$(stat -Lc '%G' "$resolved_path" 2>/dev/null) || group=unknown

        if [[ "$mode" =~ ^[0-7]+$ ]] &&
            (( (8#$mode) & 04000 )); then
            warning='WARNING: SUID bit set'
        fi
        printf '  %s: %s (%s; owner %s:%s)\n' \
            "$resolved_path" "$permissions" "$warning" "$owner" "$group"
    done
    printf '\n'
}

printf '=== Living off the Land Binaries Audit ===\n\n'
printf 'Checking GTFOBins candidates...\n\n'

audit_group 'File Readers (can read sensitive files):' \
    'cat|OK' \
    'less|OK' \
    'vim|WARNING: Can escape to shell'

audit_group 'Shell Escapes:' \
    'python3|WARNING: Can spawn shells' \
    'perl|WARNING: Can spawn shells' \
    'awk|OK'

audit_group 'Network Tools:' \
    'wget|WARNING: Can download payloads' \
    'curl|WARNING: Can download payloads'

printf 'Note: These binaries are legitimate but should be monitored.\n'
printf 'See https://gtfobins.github.io/ for abuse techniques.\n'
