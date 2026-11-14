#!/bin/bash

# Je mets à niveau seulement les candidats venant du dépôt de sécurité.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi
for command_name in apt-get apt-cache dpkg-query dpkg; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise absente: %s\n' "$command_name" >&2
        exit 1
    fi
done
if [ ! -r /etc/os-release ]; then
    printf '[ERROR] Impossible de lire /etc/os-release.\n' >&2
    exit 1
fi
release=$(awk -F= '$1 == "VERSION_CODENAME" { gsub(/"/, "", $2); print $2 }' \
    /etc/os-release)
if [ -z "$release" ]; then
    printf '[ERROR] Version de distribution introuvable.\n' >&2
    exit 1
fi
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

declare -A security_versions=()

collect_security_packages()
{
    local plan_file="$1"
    local package candidate_version candidate policy_output
    security_packages=()
    security_versions=()

    while IFS=$'\t' read -r package candidate_version; do
        [ -n "$package" ] || continue
        policy_output=$(apt-cache policy "$package") || continue
        candidate=$(awk '/Candidate:/ { print $2; exit }' \
            <<< "$policy_output")
        [ "$candidate" = "$candidate_version" ] || continue
        if awk -v version="$candidate" '
            $1 == "***" && $2 == version { candidate_seen = 1; next }
            candidate_seen && /-security([/[:space:]]|$)/ {
                found = 1
                exit
            }
            candidate_seen && $1 ~ /^[0-9]/ { candidate_seen = 0 }
            END { exit !found }
        ' <<< "$policy_output"; then
            security_packages+=("$package")
            security_versions["$package"]=$candidate
        fi
    done < <(awk '
        $1 == "Inst" {
            package = $2
            version = $4
            gsub(/[()]/, "", version)
            print package "\t" version
        }
    ' "$plan_file")
}

printf '=== Security Updates ===\n'
printf 'Fetching security update list...\n'
if ! apt-get update; then
    printf '[ERROR] Impossible de rafraîchir les index APT.\n' >&2
    exit 1
fi
if ! apt-get -s -o "APT::Default-Release=$release-security" \
    upgrade >"$temporary_directory/plan" 2>&1; then
    printf '[ERROR] Simulation des correctifs échouée.\n' >&2
    cat "$temporary_directory/plan" >&2
    exit 1
fi

collect_security_packages "$temporary_directory/plan"

printf 'Source: %s-security\n' "$release"
if [ "${#security_packages[@]}" -eq 0 ]; then
    printf 'No applicable security-only package updates found.\n'
    exit 0
fi
printf 'Available security updates: %s packages\n' \
    "${#security_packages[@]}"
printf 'Packages: %s\n' "${security_packages[*]}"
printf 'Applying only simulated security package candidates...\n'
if ! DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade \
    -o "APT::Default-Release=$release-security" \
    "${security_packages[@]}"; then
    printf '[ERROR] Installation des correctifs de sécurité échouée.\n' >&2
    exit 1
fi
printf 'Security updates installed successfully.\n'

verification_failed=0
printf '\nVerification:\n'
for package in "${security_packages[@]}"; do
    installed_version=$(dpkg-query -W -f='${Version}' "$package" \
        2>/dev/null) || {
        printf '  %s: unable to read installed version\n' "$package"
        verification_failed=1
        continue
    }
    if [ "$installed_version" = "${security_versions[$package]}" ]; then
        printf '  %s: %s (CURRENT)\n' "$package" "$installed_version"
    else
        printf '  %s: expected %s, found %s\n' "$package" \
            "${security_versions[$package]}" "$installed_version"
        verification_failed=1
    fi
done

if ! apt-get -s -o "APT::Default-Release=$release-security" upgrade \
    >"$temporary_directory/pending-plan" 2>&1; then
    printf '[ERROR] Contrôle des mises à jour restantes échoué.\n' >&2
    exit 1
fi
collect_security_packages "$temporary_directory/pending-plan"
pending_count=${#security_packages[@]}
printf '  Pending security updates: %s\n' "$pending_count"
if [ "$pending_count" -gt 0 ]; then
    printf '[ERROR] Des mises à jour de sécurité restent disponibles.\n' >&2
    verification_failed=1
fi
if [ "$verification_failed" -ne 0 ]; then
    printf '[ERROR] La vérification des paquets mis à jour a échoué.\n' >&2
    exit 1
fi
printf 'Security updates applied successfully.\n'
