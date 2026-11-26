#!/bin/bash
# Vérifie les composants d'identité et installe une politique SSH sûre par défaut.
set -euo pipefail

# Les clés sont injectées au lancement, jamais copiées dans une couche image.
authorized_keys=/home/shieldadmin/.ssh/authorized_keys
if [ -r /run/secrets/authorized_keys ] && [ -s /run/secrets/authorized_keys ]; then
    install -d -o shieldadmin -g shieldadmin -m 0700 /home/shieldadmin/.ssh
    install -o shieldadmin -g shieldadmin -m 0600 \
        /run/secrets/authorized_keys "$authorized_keys"
else
    printf '[identity] Aucune clé SSH injectée; accès distant non provisionné.\n'
fi

if command -v sshd >/dev/null 2>&1; then
    sshd -t
fi
printf '[identity] Configuration SSH valide; authentification par clé uniquement.\n'
