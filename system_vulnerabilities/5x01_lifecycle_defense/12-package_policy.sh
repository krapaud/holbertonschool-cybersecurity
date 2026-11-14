#!/bin/bash

# J’affiche les versions candidates et leurs dépôts pour un paquet APT.

set -o pipefail

if [ "$#" -ne 1 ]; then
    printf 'Usage: %s package-name\n' "${0##*/}" >&2
    exit 2
fi
if ! command -v apt-cache >/dev/null 2>&1; then
    printf '[ERROR] apt-cache est introuvable.\n' >&2
    exit 1
fi

package=$1
if [[ ! "$package" =~ ^[a-zA-Z0-9][a-zA-Z0-9.+:-]*$ ]]; then
    printf '[ERROR] Nom de paquet invalide.\n' >&2
    exit 2
fi
policy=$(apt-cache policy "$package" 2>&1) || {
    printf '[ERROR] apt-cache policy a échoué pour %s.\n' "$package" >&2
    exit 1
}
if ! grep -q 'Candidate:' <<< "$policy"; then
    printf '[ERROR] Aucun paquet candidat trouvé pour %s.\n' "$package" >&2
    exit 1
fi

printf '=== Package Policy: %s ===\n' "$package"
printf '%s\n' "$policy"
candidate=$(awk '/Candidate:/ { print $2; exit }' <<< "$policy")
if grep -Eqi 'security|-[^ ]*security' <<< "$policy"; then
    printf '\nSecurity update: available in configured package sources\n'
else
    printf '\nSecurity update: no security origin identified in policy output\n'
fi
printf 'Recommendation: review candidate %s and its origin before upgrading.\n' \
    "$candidate"
