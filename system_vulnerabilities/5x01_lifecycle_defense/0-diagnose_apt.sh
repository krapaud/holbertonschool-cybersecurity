#!/bin/bash

# Ce diagnostic observe APT et DPKG sans modifier les paquets ni les verrous.

set -o pipefail

if ! command -v dpkg-query >/dev/null 2>&1 ||
    ! command -v apt-get >/dev/null 2>&1; then
    printf '[ERROR] apt-get ou dpkg-query est introuvable.\n' >&2
    exit 1
fi

lock_files=(
    /var/lib/dpkg/lock-frontend
    /var/lib/dpkg/lock
    /var/lib/apt/lists/lock
    /var/cache/apt/archives/lock
)

lock_issue=0
half_configured=()
half_installed=()
config_files=()
source_invalid=()
temporary_directory=''

cleanup()
{
    if [ -n "$temporary_directory" ]; then
        rm -rf -- "$temporary_directory"
    fi
}
trap cleanup EXIT

printf '=== APT/DPKG Diagnostic ===\n'
printf 'Lock files:\n'
for lock_file in "${lock_files[@]}"; do
    if [ ! -e "$lock_file" ]; then
        printf '  %s: OK (absent)\n' "$lock_file"
        continue
    fi
    if command -v fuser >/dev/null 2>&1 && fuser -s "$lock_file"; then
        printf '  %s: PRESENT (in use)\n' "$lock_file"
        lock_issue=1
    else
        printf '  %s: PRESENT (stale candidate; verify before removal)\n' \
            "$lock_file"
        lock_issue=1
    fi
done

while IFS=$'\t' read -r status package; do
    case "$status" in
        *half-configured*) half_configured+=("$package") ;;
        *half-installed*|*unpacked*) half_installed+=("$package") ;;
        *config-files*) config_files+=("$package") ;;
    esac
done < <(dpkg-query -W -f='${Status}\t${binary:Package}\n' 2>/dev/null)

printf '\nPackage states:\n'
printf '  Half-configured: %s packages\n' "${#half_configured[@]}"
for package in "${half_configured[@]}"; do
    printf '    - %s\n' "$package"
done
printf '  Half-installed or unpacked: %s packages\n' \
    "${#half_installed[@]}"
for package in "${half_installed[@]}"; do
    printf '    - %s\n' "$package"
done
printf '  Config-files only: %s packages\n' "${#config_files[@]}"

audit_output=$(dpkg --audit 2>&1)
audit_status=$?
pending_updates=0
if compgen -G '/var/lib/dpkg/updates/*' >/dev/null; then
    pending_updates=1
fi
printf '\nInterrupted operations:\n'
if [ "$audit_status" -ne 0 ] || [ -n "$audit_output" ] ||
    [ "$pending_updates" -eq 1 ]; then
    printf '  DPKG reports unfinished work (INTERRUPTED)\n'
    if [ -n "$audit_output" ]; then
        printf '%s\n' "$audit_output" | sed 's/^/    /'
    fi
    if [ "$pending_updates" -eq 1 ]; then
        printf '  Pending files exist in /var/lib/dpkg/updates/\n'
    fi
    interrupted=1
else
    printf '  No unfinished DPKG operation reported\n'
    interrupted=0
fi
last_apt_start=$(awk '
    /^Start-Date:/ {
        start = $0
        ended = 0
    }
    /^End-Date:/ {
        ended = 1
        last_complete = start " " $0
    }
    END {
        if (start != "" && ended == 0) {
            print start " (INTERRUPTED)"
        } else if (last_complete != "") {
            print last_complete
        }
    }
' /var/log/apt/history.log 2>/dev/null)
if [ -n "$last_apt_start" ]; then
    printf 'Last APT operation: %s\n' "$last_apt_start"
else
    printf 'Last APT operation: unavailable in /var/log/apt/history.log\n'
fi

printf '\nAPT sources:\n'
source_files=()
valid_source_count=0
if [ -f /etc/apt/sources.list ]; then
    source_files+=(/etc/apt/sources.list)
fi
while IFS= read -r -d '' source_file; do
    source_files+=("$source_file")
done < <(find /etc/apt/sources.list.d -maxdepth 1 -type f \
    \( -name '*.list' -o -name '*.sources' \) -print0 2>/dev/null)

for source_file in "${source_files[@]}"; do
    if [[ "$source_file" == *.list ]]; then
        while IFS= read -r source_line; do
            [[ "$source_line" =~ ^[[:space:]]*# ]] && continue
            [[ "$source_line" =~ ^[[:space:]]*$ ]] && continue
            if [[ ! "$source_line" =~ ^[[:space:]]*deb(-src)?[[:space:]]+ ]]; then
                source_invalid+=("$source_file (syntaxe invalide)")
                break
            fi
            valid_source_count=$((valid_source_count + 1))
        done < "$source_file"
    elif ! grep -Eq '^[[:space:]]*(Types|URIs|Suites|Components):' \
        "$source_file" 2>/dev/null; then
        source_invalid+=("$source_file (format deb822 invalide)")
    else
        source_entries=$(grep -Ec '^[[:space:]]*URIs:' "$source_file")
        valid_source_count=$((valid_source_count + source_entries))
    fi
done

if ! temporary_directory=$(mktemp -d 2>/dev/null); then
    printf '[ERROR] Impossible de créer les fichiers temporaires APT.\n' >&2
    exit 1
fi
mkdir -p "$temporary_directory/lists/partial" \
    "$temporary_directory/archives/partial"
if timeout 60 apt-get -o Debug::NoLocking=1 \
    -o "Dir::State::lists=$temporary_directory/lists" \
    -o "Dir::Cache::archives=$temporary_directory/archives" \
    update >"$temporary_directory/update.log" 2>&1; then
    printf '  Reachable/valid entries: %s\n' "$valid_source_count"
else
    source_invalid+=("échec de apt-get update en mode temporaire")
    printf '  APT update check: FAILED\n'
    tail -n 8 "$temporary_directory/update.log" | sed 's/^/    /'
fi
printf '  Invalid or unreachable: %s\n' "${#source_invalid[@]}"
for source in "${source_invalid[@]}"; do
    printf '    - %s\n' "$source"
done

printf '\nDPKG database: '
if [ "$audit_status" -eq 0 ] && [ -z "$audit_output" ] &&
    [ "$pending_updates" -eq 0 ] &&
    [ "${#half_configured[@]}" -eq 0 ] &&
    [ "${#half_installed[@]}" -eq 0 ]; then
    printf 'CONSISTENT\n'
    database_issue=0
else
    printf 'INCONSISTENT\n'
    database_issue=1
fi

if [ "$lock_issue" -eq 1 ] || [ "$interrupted" -eq 1 ] ||
    [ "$database_issue" -eq 1 ] || [ "${#source_invalid[@]}" -gt 0 ]; then
    printf 'Action required: YES\n'
else
    printf 'Action required: NO\n'
fi
