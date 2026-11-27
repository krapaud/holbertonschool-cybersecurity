#!/bin/bash
# Je démarre les services nécessaires au conteneur.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo '[ERREUR] Lance ce script en root dans le conteneur.' >&2
    exit 1
fi

if ! /opt/hardened-shield/scripts/init-identity.sh; then
    echo '[ERREUR] La configuration des comptes a échoué.' >&2
    exit 2
fi

# Les clés d'hôte sont créées au démarrage, dans le dossier temporaire.
mkdir -p /run/ssh-host-keys /run/sshd /var/lib/nginx
ssh-keygen -q -t ed25519 -N '' \
    -f /run/ssh-host-keys/ssh_host_ed25519_key
chmod 600 /run/ssh-host-keys/ssh_host_ed25519_key

# Je vérifie les configurations avant de lancer les services.
if ! nginx -t >/dev/null 2>&1; then
    echo '[ERREUR] La configuration Nginx est invalide.' >&2
    exit 3
fi
if ! sshd -t >/dev/null 2>&1; then
    echo '[ERREUR] La configuration SSH est invalide.' >&2
    exit 3
fi

if ! service rsyslog start >/dev/null 2>&1; then
    echo '[ERREUR] Le service rsyslog n’a pas démarré.' >&2
    exit 3
fi
if ! service ssh start >/dev/null 2>&1; then
    echo '[ERREUR] Le service SSH n’a pas démarré.' >&2
    exit 3
fi
if ! service fail2ban start >/dev/null 2>&1; then
    echo '[ERREUR] Le service Fail2ban n’a pas démarré.' >&2
    exit 3
fi

if ! fail2ban-client status sshd >/dev/null 2>&1; then
    echo '[ERREUR] Le jail SSH de Fail2ban ne fonctionne pas.' >&2
    exit 3
fi

if ! service ssh status >/dev/null 2>&1; then
    echo '[ERREUR] Le service SSH ne fonctionne pas.' >&2
    exit 3
fi

# Nginx reste au premier plan pour que Docker suive le service Web.
nginx -g 'daemon off;' &
nginx_pid=$!
web_ready=0

for attempt in 1 2 3 4 5; do
    if curl --fail --silent http://127.0.0.1/health | grep -qx 'ok'; then
        web_ready=1
        break
    fi
    sleep 1
done

if [ "$web_ready" -ne 1 ]; then
    echo '[ERREUR] Le contrôle HTTP /health a échoué.' >&2
    exit 4
fi

echo '[RÉUSSI] SSH, Nginx et Fail2ban sont démarrés.'
wait "$nginx_pid"
