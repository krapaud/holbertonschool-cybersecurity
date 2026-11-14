#!/bin/bash

# Je sauvegarde l’état avant de rétrograder un paquet vers une version précise.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi
if [ "$#" -ne 2 ]; then
    printf 'Usage: %s package version\n' "${0##*/}" >&2
    exit 2
fi
package=$1
version=$2
if [[ ! "$package" =~ ^[a-zA-Z0-9][a-zA-Z0-9.+:-]*$ ]] ||
    [[ ! "$version" =~ ^[a-zA-Z0-9.+:~_-]+$ ]]; then
    printf '[ERROR] Nom de paquet ou version invalide.\n' >&2
    exit 2
fi
if ! apt-cache madison "$package" | awk -v wanted="$version" \
    '$3 == wanted { found = 1 } END { exit !found }'; then
    printf '[ERROR] Version %s de %s absente des dépôts configurés.\n' \
        "$version" "$package" >&2
    exit 1
fi
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
backup_directory=/var/backups/lifecycle-defense/rollback-$timestamp
mkdir -p "$backup_directory" || exit 1
dpkg-query -W -f='${binary:Package}\t${Version}\n' \
    > "$backup_directory/packages-before.tsv" || exit 1
tar -czf "$backup_directory/etc.tar.gz" /etc 2>/dev/null || {
    printf '[ERROR] Snapshot de /etc impossible.\n' >&2
    exit 1
}
printf 'Backup: %s\n' "$backup_directory"
printf 'Simulating rollback: %s=%s\n' "$package" "$version"
apt-get -s install "$package=$version" || exit 1
read -r -p 'Confirmer la rétrogradation simulée ? [y/N] ' confirmation
case "$confirmation" in
    y|Y|yes|YES) ;;
    *) printf 'Rollback annulé.\n'; exit 0 ;;
esac
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    --allow-downgrades "$package=$version" || {
    printf '[ERROR] Rétrogradation échouée. Consultez les sauvegardes.\n' >&2
    exit 1
}
installed=$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null)
if [ "$installed" != "$version" ]; then
    printf '[ERROR] Version vérifiée inattendue: %s\n' "$installed" >&2
    exit 1
fi
printf 'Rollback verified: %s %s\n' "$package" "$installed"
