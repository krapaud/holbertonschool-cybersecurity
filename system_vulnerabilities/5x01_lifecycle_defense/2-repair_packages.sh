#!/bin/bash

# Je termine les configurations interrompues et vérifie les dépendances APT.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi
if ! command -v dpkg >/dev/null 2>&1 ||
    ! command -v apt-get >/dev/null 2>&1; then
    printf '[ERROR] dpkg ou apt-get est introuvable.\n' >&2
    exit 1
fi
if pgrep -x apt >/dev/null || pgrep -x apt-get >/dev/null ||
    pgrep -x dpkg >/dev/null || pgrep -x unattended-upgrade >/dev/null; then
    printf '[ERROR] Une opération de paquets est déjà en cours.\n' >&2
    exit 1
fi

printf '=== Package Repair ===\n'
printf 'Configuring interrupted packages...\n'
if ! dpkg --configure -a; then
    printf '[ERROR] La configuration DPKG a échoué.\n' >&2
    exit 1
fi
printf 'Fixing broken dependencies...\n'
if ! apt-get -f install -y; then
    printf '[ERROR] La réparation des dépendances APT a échoué.\n' >&2
    exit 1
fi

half_configured=$(dpkg-query -W -f='${db:Status-Status}\n' 2>/dev/null |
    awk '$0 == "half-configured" { count++ } END { print count+0 }')
broken_dependencies=$(apt-get check 2>&1)
if [ $? -ne 0 ]; then
    printf '[ERROR] apt-get check signale des dépendances cassées.\n' >&2
    printf '%s\n' "$broken_dependencies" >&2
    exit 1
fi
printf '\nVerification:\n'
printf '  Half-configured packages: %s\n' "$half_configured"
printf '  Broken dependencies: 0\n'
if [ "$half_configured" -ne 0 ]; then
    printf '[ERROR] Des paquets restent en état half-configured.\n' >&2
    exit 1
fi
printf '  Package database: CONSISTENT\n'
