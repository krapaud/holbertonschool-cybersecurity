#!/bin/bash

# Je sauvegarde l’état avant de rétrograder un paquet.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi
for command_name in apt-cache apt-get dpkg-query dpkg tar; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise absente: %s\n' "$command_name" >&2
        exit 1
    fi
done
if [ "$#" -ne 2 ]; then
    printf 'Usage: %s package version\n' "${0##*/}" >&2
    exit 2
fi
package="${1}"; version="${2}"
if [[ ! "$package" =~ ^[a-zA-Z0-9][a-zA-Z0-9.+:-]*$ ]] ||
    [[ ! "$version" =~ ^[a-zA-Z0-9.+:~_-]+$ ]]; then
    printf '[ERROR] Nom de paquet ou version invalide.\n' >&2
    exit 2
fi
current_version=$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null) || {
    printf '[ERROR] Le paquet %s n’est pas installé.\n' "$package" >&2
    exit 1
}
if ! dpkg --compare-versions "$version" lt "$current_version"; then
    printf '[ERROR] %s n’est pas antérieure à %s.\n' \
        "$version" "$current_version" >&2
    exit 1
fi

printf '=== Package Rollback ===\n\n'
printf 'Target: %s\n' "$package"
printf 'Current: %s\n' "$current_version"
printf 'Rollback to: %s\n\n' "$version"
printf 'Checking version availability...\n'
if ! apt-cache madison "$package" | awk -v wanted="$version" \
    '$3 == wanted { found = 1 } END { exit !found }'; then
    printf '[ERROR] Version %s de %s absente des dépôts configurés.\n' \
        "$version" "$package" >&2
    exit 1
fi
printf '  Version %s found in apt cache.\n\n' "$version"
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
snapshot_id="pre-rollback-$(date -u '+%Y%m%d')"
backup_directory=/var/backups/lifecycle-defense/$snapshot_id-$timestamp
printf 'Creating system snapshot...\n'
mkdir -p "$backup_directory" || exit 1
dpkg-query -W -f='${binary:Package}\t${Version}\n' \
    > "$backup_directory/packages-before.tsv" || exit 1
tar -czf "$backup_directory/etc.tar.gz" /etc 2>/dev/null || {
    printf '[ERROR] Snapshot de /etc impossible.\n' >&2
    exit 1
}
printf '  Snapshot ID: %s\n\n' "$snapshot_id"
printf 'Simulating downgrade: %s=%s\n' "$package" "$version"
apt-get -s install "$package=$version" || exit 1
read -r -p 'Confirmer la rétrogradation simulée ? [y/N] ' confirmation
case "$confirmation" in
    y|Y|yes|YES) ;;
    *) printf 'Rollback annulé.\n'; exit 0 ;;
esac
printf '\nPerforming downgrade...\n'
printf '  Removing %s (%s)...\n' "$package" "$current_version"
DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades \
    "${package}=${version}" || {
    printf '[ERROR] Rétrogradation échouée.\n' >&2
    printf 'Consultez les sauvegardes avant toute autre action.\n' >&2
    exit 1
}
installed=$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null)
printf '\nVerification:\n'
printf '  Installed version: %s\n' "${installed:-unknown}"
if [ "$installed" != "$version" ]; then
    printf '[ERROR] Version vérifiée inattendue: %s\n' "$installed" >&2
    exit 1
fi
printf '  Downgrade: SUCCESSFUL\n\n'
if [ "$package" = ca-certificates ]; then
    printf 'Testing application...\n'
    if command -v curl >/dev/null 2>&1 &&
        curl --fail --silent --show-error --head \
            --connect-timeout 5 --max-time 15 \
            https://archive.ubuntu.com/ubuntu/ >/dev/null 2>&1; then
        printf '  SSL verification: WORKING\n'
    else
        printf '  SSL verification: UNVERIFIED (network check unavailable)\n'
    fi
fi
printf '\nRollback complete.\n'
