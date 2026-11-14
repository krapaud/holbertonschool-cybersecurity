#!/bin/bash

# Je liste les paquets bloqués ou retire un blocage demandé.

set -o pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'Usage: %s list | unhold package\n' "${0##*/}" >&2
    exit 2
fi
case "$1" in
    list)
        [ "$#" -eq 1 ] || exit 2
        printf '=== Held Packages ===\n'
        apt-mark showhold | while IFS= read -r package; do
            [ -n "$package" ] || continue
            apt-cache policy "$package" | awk -v package="$package" '
                /Installed:/ { installed = $2 }
                END {
                    printf "%s installed=%s\n", package, installed
                }
            '
        done
        ;;
    unhold)
        [ "$#" -eq 2 ] || exit 2
        package=$2
        if [[ ! "$package" =~ ^[a-zA-Z0-9][a-zA-Z0-9.+:-]*$ ]]; then
            printf '[ERROR] Nom de paquet invalide.\n' >&2
            exit 2
        fi
        apt-mark unhold "$package" || exit 1
        printf '%s UNHOLD %s\n' \
            "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$package" \
            >> /var/log/lifecycle-defense.log || exit 1
        printf 'Package unheld: %s\n' "$package"
        ;;
    *)
        printf 'Usage: %s list | unhold package\n' "${0##*/}" >&2
        exit 2
        ;;
esac
