#!/bin/bash

# Je teste chaque fichier de dépôts isolément et garde une copie avant retrait.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi
for command_name in apt-get mktemp timeout; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise absente: %s\n' "$command_name" >&2
        exit 1
    fi
done
if pgrep -x apt >/dev/null || pgrep -x apt-get >/dev/null ||
    pgrep -x dpkg >/dev/null || pgrep -x unattended-upgrade >/dev/null; then
    printf '[ERROR] Une opération de paquets est déjà en cours.\n' >&2
    exit 1
fi

temporary_directory=$(mktemp -d) || {
    printf '[ERROR] Impossible de créer un dossier temporaire.\n' >&2
    exit 1
}
cleanup()
{
    rm -rf -- "$temporary_directory"
}
trap cleanup EXIT
log_file=/var/log/lifecycle-defense.log
timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
valid_sources=0
disabled_sources=0
source_files=()
[ ! -f /etc/apt/sources.list ] || source_files+=(/etc/apt/sources.list)
while IFS= read -r -d '' source_file; do
    source_files+=("$source_file")
done < <(find /etc/apt/sources.list.d -maxdepth 1 -type f \
    \( -name '*.list' -o -name '*.sources' \) -print0 2>/dev/null)

printf '=== APT Sources Validation ===\n'
for source_file in "${source_files[@]}"; do
    source_name=${source_file##*/}
    source_lists="$temporary_directory/$source_name-lists"
    source_archives="$temporary_directory/$source_name-archives"
    mkdir -p "$source_lists/partial" "$source_archives/partial"
    if timeout 90 apt-get -o Debug::NoLocking=1 \
        -o "Dir::Etc::sourcelist=$source_file" \
        -o Dir::Etc::sourceparts=- \
        -o "Dir::State::lists=$source_lists" \
        -o "Dir::Cache::archives=$source_archives" \
        update >"$temporary_directory/$source_name.log" 2>&1; then
        count=$(grep -Ec '^[[:space:]]*deb(-src)?[[:space:]]+' \
            "$source_file" 2>/dev/null || true)
        if [[ "$source_file" == *.sources ]]; then
            count=$(grep -Ec '^[[:space:]]*URIs:' "$source_file" || true)
        fi
        valid_sources=$((valid_sources + count))
        printf '  %s: %s entries valid\n' "$source_name" "$count"
        continue
    fi

    printf '  %s: INVALID (APT could not update this source)\n' "$source_name"
    printf '  Action: backup and disable %s\n' "$source_name"
    if [[ "$source_file" == /etc/apt/sources.list.d/* ]]; then
        backup_file="$source_file.$(date -u '+%Y%m%dT%H%M%SZ').bak"
        disabled_file="$source_file.disabled"
        if [ -e "$disabled_file" ]; then
            printf '[ERROR] Destination already exists: %s\n' "$disabled_file" >&2
            exit 1
        fi
        if ! cp -a -- "$source_file" "$backup_file" ||
            ! mv -- "$source_file" "$disabled_file"; then
            printf '[ERROR] Sauvegarde ou désactivation impossible: %s\n' \
                "$source_file" >&2
            exit 1
        fi
        printf '%s disabled=%s backup=%s\n' "$timestamp" \
            "$disabled_file" "$backup_file" >> "$log_file"
        disabled_sources=$((disabled_sources + 1))
    else
        printf '[ERROR] Une entrée invalide est dans sources.list; '
        printf 'aucune désactivation globale automatique.\n' >&2
        exit 1
    fi
done

printf 'Running apt update...\n'
if ! apt-get update; then
    printf '[ERROR] Les dépôts restants ne se mettent pas à jour.\n' >&2
    exit 1
fi
printf 'All repositories updated successfully.\n'
printf 'Summary: Valid sources: %s Disabled sources: %s\n' \
    "$valid_sources" "$disabled_sources"
