#!/bin/bash
# Je réserve les outils réseau installés à l’administration système.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] %s %s.\n' \
        'Exécute ce script avec sudo' 'dans la VM de laboratoire' >&2
    exit 1
fi

for command_name in chmod chown readlink stat; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise introuvable: %s\n' \
            "$command_name" >&2
        exit 1
    fi
done

tool_paths=(
    /usr/bin/nc
    /usr/bin/ncat
    /usr/bin/netcat
    /usr/bin/nmap
    /usr/bin/tcpdump
    /usr/sbin/tcpdump
    /bin/nc
    /bin/nmap
    /bin/tcpdump
)
restricted_paths=()
restricted_names=()

printf '=== Network Tools Restriction ===\n\n'
printf 'Restricting access (root only)...\n'

for tool_path in "${tool_paths[@]}"; do
    [ -x "$tool_path" ] || continue
    resolved_path=$(readlink -f -- "$tool_path" 2>/dev/null) || {
        printf '[ERROR] Résolution impossible: %s\n' "$tool_path" >&2
        exit 1
    }
    [ -f "$resolved_path" ] || continue

    already_restricted=0
    for previous_path in "${restricted_paths[@]}"; do
        if [ "$previous_path" = "$resolved_path" ]; then
            already_restricted=1
            break
        fi
    done
    [ "$already_restricted" -eq 0 ] || continue

    previous_mode=$(stat -Lc '%a' "$resolved_path" 2>/dev/null) || {
        printf '[ERROR] Lecture des permissions impossible: %s\n' \
            "$tool_path" >&2
        exit 1
    }
    if ! chown root:root "$resolved_path" ||
        ! chmod 0750 "$resolved_path"; then
        printf '[ERROR] Restriction impossible: %s\n' "$tool_path" >&2
        exit 1
    fi

    current_mode=$(stat -Lc '%a' "$resolved_path" 2>/dev/null) || {
        printf '[ERROR] Vérification impossible: %s\n' "$tool_path" >&2
        exit 1
    }
    if [ "$current_mode" != 750 ]; then
        printf '[ERROR] Mode inattendu pour %s: %s\n' \
            "$tool_path" "$current_mode" >&2
        exit 1
    fi

    printf '  %s: 0%s (was 0%s)\n' \
        "$tool_path" "$current_mode" "$previous_mode"
    restricted_paths+=("$resolved_path")
    restricted_names+=("${tool_path##*/}")
done

printf '\nVerification:\n'
if [ "${#restricted_paths[@]}" -eq 0 ]; then
    printf '  No matching network tools found\n'
else
    for path_index in "${!restricted_paths[@]}"; do
        restricted_path=${restricted_paths[$path_index]}
        tool_name=${restricted_names[$path_index]}
        permissions=$(stat -Lc '%A %U %G' "$restricted_path") || {
            printf '[ERROR] Vérification impossible: %s\n' \
                "$restricted_path" >&2
            exit 1
        }
        if [ "$(stat -Lc '%a' "$restricted_path")" != 750 ] ||
            [ "$(stat -Lc '%U:%G' "$restricted_path")" != root:root ]; then
            printf '[ERROR] Permissions ou propriétaire incorrects: %s\n' \
                "$restricted_path" >&2
            exit 1
        fi
        printf '  %s: %s\n' "$tool_name" "$permissions"
    done
fi

printf '\nNetwork tools restricted to root.\n'
printf 'Regular users can no longer execute these binaries.\n'
