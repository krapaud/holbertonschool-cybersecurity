#!/bin/bash

# Je simule les mises à jour automatiques sans installer de paquet.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi
if ! command -v unattended-upgrade >/dev/null 2>&1; then
    printf '[ERROR] unattended-upgrade est introuvable.\n' >&2
    exit 1
fi

output=$(unattended-upgrade --dry-run --debug 2>&1) || {
    printf '%s\n' "$output" >&2
    printf '[ERROR] La simulation unattended-upgrades a échoué.\n' >&2
    exit 1
}
printf '=== Unattended Upgrade Dry Run ===\n'
printf '%s\n' "$output"
if grep -Eqi 'linux-image|linux-generic' <<< "$output"; then
    printf '\nReboot required: likely, because a kernel package is selected\n'
else
    printf '\nReboot required: no kernel update identified in simulation\n'
fi
printf 'No packages were installed by this dry run.\n'
