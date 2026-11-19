#!/bin/bash
# Je retire le bit SUID superflu en gardant les outils essentiels.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] %s %s.\n' \
        'Exécute ce script avec sudo' 'dans la VM de laboratoire' >&2
    exit 1
fi

for command_name in find stat chmod readlink mktemp; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise introuvable: %s\n' \
            "$command_name" >&2
        exit 1
    fi
done

temporary_directory=$(mktemp -d) || {
    printf '[ERROR] Impossible de créer un dossier temporaire.\n' >&2
    exit 1
}
trap 'rm -rf -- "$temporary_directory"' EXIT

suid_before_file=$temporary_directory/suid-before
suid_after_file=$temporary_directory/suid-after
find_errors=$temporary_directory/find-errors
essential_paths=()
essential_locations=(/usr/bin/sudo /usr/bin/passwd /usr/bin/su)
before_total=0
after_total=0
changes_failed=0

for essential_location in "${essential_locations[@]}"; do
    resolved_location=$(readlink -f -- "$essential_location" 2>/dev/null) ||
        resolved_location=
    if [ -n "$resolved_location" ] && [ -x "$resolved_location" ]; then
        essential_paths+=("$resolved_location")
    fi
done

if ! find / -xdev -type f -perm -4000 -print0 \
    > "$suid_before_file" 2> "$find_errors"; then
    printf '[ERROR] Recherche des binaires SUID échouée.\n' >&2
    exit 1
fi

printf '=== SUID Neutralization ===\n\n'
printf 'Preserving essential SUID (DO NOT TOUCH):\n'
for essential_location in "${essential_locations[@]}"; do
    printf '  %s\n' "$essential_location"
done

printf '\nRemoving SUID from non-essential binaries...\n'
while IFS= read -r -d '' binary_path; do
    before_total=$((before_total + 1))
    resolved_path=$(readlink -f -- "$binary_path" 2>/dev/null) || {
        printf '[ERROR] Résolution impossible: %s\n' "$binary_path" >&2
        changes_failed=1
        continue
    }

    preserve_binary=0
    for essential_path in "${essential_paths[@]}"; do
        if [ "$resolved_path" = "$essential_path" ]; then
            preserve_binary=1
            break
        fi
    done
    [ "$preserve_binary" -eq 0 ] || continue

    if ! chmod u-s "$binary_path"; then
        printf '[ERROR] Retrait du bit SUID impossible: %s\n' \
            "$binary_path" >&2
        changes_failed=1
        continue
    fi

    case "$binary_path" in
        /usr/local/*|/opt/*)
            reason='CUSTOM - HIGH RISK'
            ;;
        */mount|*/umount)
            reason='admin can use sudo'
            ;;
        */newgrp)
            reason='not needed'
            ;;
        *)
            reason='not essential for this server'
            ;;
    esac
    printf '  %s: SUID removed (%s)\n' "$binary_path" "$reason"
done < "$suid_before_file"

printf '\nVerification:\n'
for utility_name in mount umount; do
    utility_path=$(command -v "$utility_name" 2>/dev/null) || {
        printf '  %s: Not found\n' "$utility_name"
        continue
    }
    resolved_path=$(readlink -f -- "$utility_path" 2>/dev/null) || {
        printf '[ERROR] Résolution impossible: %s\n' "$utility_path" >&2
        changes_failed=1
        continue
    }
    mode=$(stat -c '%a' "$resolved_path" 2>/dev/null) || mode=unknown
    if [[ "$mode" =~ ^[0-7]+$ ]] && (( (8#$mode) & 04000 )); then
        printf '  %s: SUID still set (mode %s)\n' \
            "$utility_name" "$mode"
        changes_failed=1
    else
        permissions=$(stat -c '%A' "$resolved_path" 2>/dev/null) ||
            permissions=unknown
        printf '  %s: %s (no SUID)\n' "$utility_name" "$permissions"
    fi
done

if ! find / -xdev -type f -perm -4000 -print0 \
    > "$suid_after_file" 2>> "$find_errors"; then
    printf '[ERROR] Vérification finale des binaires SUID échouée.\n' >&2
    exit 1
fi
while IFS= read -r -d '' binary_path; do
    after_total=$((after_total + 1))
done < "$suid_after_file"

printf '\nSUID binaries reduced from %s to %s.\n' \
    "$before_total" "$after_total"
if [ "$changes_failed" -ne 0 ]; then
    printf '[ERROR] Certaines vérifications ont échoué.\n' >&2
    exit 1
fi
