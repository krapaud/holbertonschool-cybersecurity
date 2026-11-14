#!/bin/bash

# Je mets à niveau seulement les candidats venant du dépôt de sécurité.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi
for command_name in apt-get apt-cache; do
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

printf '=== Security Updates ===\n'
if ! apt-get update; then
    printf '[ERROR] Impossible de rafraîchir les index APT.\n' >&2
    exit 1
fi
printf 'Fetching security update list...\n'
if ! apt-get -s -o "APT::Default-Release=$release-security" \
    upgrade >"$temporary_directory/plan" 2>&1; then
    printf '[ERROR] Impossible de simuler les mises à jour de sécurité.\n' >&2
    cat "$temporary_directory/plan" >&2
    exit 1
fi

security_packages=()
while read -r package candidate_version; do
    [ -n "$package" ] || continue
    candidate=$(apt-cache policy "$package" | awk '/Candidate:/ { print $2; exit }')
    [ "$candidate" = "$candidate_version" ] || continue
    if apt-cache policy "$package" | awk -v version="$candidate" '
        $1 == "***" && $2 == version { candidate_seen = 1; next }
        candidate_seen && /-security([/[:space:]]|$)/ { found = 1; exit }
        candidate_seen && $1 ~ /^[0-9]/ { candidate_seen = 0 }
        END { exit !found }
    '; then
        security_packages+=("$package")
    fi
done < <(awk '$1 == "Inst" { package = $2; version = $4; gsub(/[()]/, "", version); print package, version }' \
    "$temporary_directory/plan")

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
    printf '[ERROR] Installation des mises à jour de sécurité échouée.\n' >&2
    exit 1
fi
printf 'Security updates installed successfully.\n'
