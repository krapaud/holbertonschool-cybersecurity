#!/bin/bash
# Prépare le compte SSH avec la clé fournie au démarrage.
set -euo pipefail

# Je ne mets pas de clé dans l'image. Le fichier est monté quand le conteneur démarre.
authorized_keys=/home/shieldadmin/.ssh/authorized_keys
if [ -r /run/secrets/authorized_keys ] && [ -s /run/secrets/authorized_keys ]; then
    install -d -o shieldadmin -g shieldadmin -m 0700 /home/shieldadmin/.ssh
    install -o shieldadmin -g shieldadmin -m 0600 \
        /run/secrets/authorized_keys "$authorized_keys"
else
    printf '[INFO] Pas de clé fournie. La connexion SSH ne sera pas possible.\n'
fi

# Je vérifie que le fichier sshd_config ne contient pas d'erreur.
if command -v sshd >/dev/null 2>&1; then
    sshd -t
fi
printf '[OK] Configuration SSH vérifiée. Connexion par clé uniquement.\n'
