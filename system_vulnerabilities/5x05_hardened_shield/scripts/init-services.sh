#!/bin/bash
# Je prépare le conteneur, puis je garde Nginx au premier plan.
set -uo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo '[ERREUR] Lance ce script en root dans le conteneur.' >&2
    exit 1
fi

for tool in curl fail2ban-client grep mkdir nginx service sleep sshd ssh-keygen; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[ERREUR] Commande manquante : $tool" >&2
        exit 1
    fi
done

# Les réglages système et PAM sont préparés dans l'image.
if /opt/hardened-shield/scripts/init-identity.sh; then
    echo '[RÉUSSI] Réglages d’identité vérifiés.'
else
    result=$?
    echo '[ERREUR] Le durcissement de l’identité a échoué.' >&2
    exit "$result"
fi

# Je crée des clés d'hôte propres à chaque conteneur.
if ! mkdir -p /run/ssh-host-keys || \
    ! ssh-keygen -q -t ed25519 -N '' \
        -f /run/ssh-host-keys/ssh_host_ed25519_key || \
    ! ssh-keygen -q -t rsa -b 3072 -N '' \
        -f /run/ssh-host-keys/ssh_host_rsa_key; then
    echo '[ERREUR] Impossible de créer les clés d’hôte SSH.' >&2
    exit 3
fi
chmod 0600 /run/ssh-host-keys/ssh_host_*_key

if ! mkdir -p /run/sshd /run/ssh-host-keys /var/lib/nginx; then
    echo '[ERREUR] Impossible de préparer les dossiers des services.' >&2
    exit 3
fi

# Je valide la configuration avant de démarrer les services.
if ! nginx -t; then
    echo '[ERREUR] La configuration Nginx est invalide.' >&2
    exit 2
fi
if ! sshd -t; then
    echo '[ERREUR] La configuration SSH est invalide.' >&2
    exit 2
fi

if ! service rsyslog start >/dev/null 2>&1; then
    echo '[ERREUR] Le service rsyslog n’a pas démarré.' >&2
    exit 3
fi

echo '[INFO] Démarrage de SSH...'
if ! service ssh start >/dev/null 2>&1; then
    echo '[ERREUR] Le service SSH n’a pas démarré.' >&2
    exit 3
fi

echo '[INFO] Démarrage de Fail2ban...'
if ! service fail2ban start >/dev/null 2>&1 || \
    ! fail2ban-client ping >/dev/null 2>&1; then
    echo '[ERREUR] Fail2ban n’a pas démarré.' >&2
    exit 3
fi
echo '[RÉUSSI] Fail2ban est actif.'

# Je vérifie que SSH répond avec sa bannière, même si le service était déjà lancé.
ssh_ready=0
for attempt in 1 2 3 4 5; do
    if exec 3<>/dev/tcp/127.0.0.1/22 2>/dev/null; then
        if IFS= read -r -t 2 ssh_banner <&3 && [[ "$ssh_banner" == SSH-* ]]; then
            ssh_ready=1
        fi
        exec 3>&- 3<&-
    fi
    if [ "$ssh_ready" -eq 1 ]; then
        break
    fi
    sleep 1
done
if [ "$ssh_ready" -ne 1 ]; then
    echo '[ERREUR] SSH ne répond pas sur le port 22.' >&2
    exit 3
fi
echo '[RÉUSSI] SSH répond sur le port 22.'

# Si Nginx tourne déjà, je vérifie son endpoint et je termine sans doublon.
if curl --fail --silent --max-time 3 http://127.0.0.1/health | grep -qx 'ok'; then
    echo '[RÉUSSI] Le contrôle HTTP /health répond.'
    echo '[RÉUSSI] Les services requis sont déjà actifs.'
    exit 0
fi

# Je garde Nginx au premier plan pour que Docker suive le processus principal.
echo '[INFO] Démarrage de Nginx...'
nginx -g 'daemon off;' >/dev/null 2>&1 &
nginx_pid=$!
web_ready=0
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if curl --fail --silent --max-time 2 http://127.0.0.1/health | grep -qx 'ok'; then
        web_ready=1
        break
    fi
    if ! kill -0 "$nginx_pid" 2>/dev/null; then
        break
    fi
    sleep 1
done

if [ "$web_ready" -ne 1 ]; then
    kill "$nginx_pid" 2>/dev/null || true
    wait "$nginx_pid" 2>/dev/null || true
    echo '[ERREUR] Le contrôle HTTP /health a échoué.' >&2
    exit 4
fi

echo '[RÉUSSI] Nginx répond sur le port 80.'
echo '[RÉUSSI] Les services requis sont actifs. Nginx reste au premier plan.'

if wait "$nginx_pid"; then
    echo '[ERREUR] Nginx s’est arrêté de façon inattendue.' >&2
    exit 4
else
    echo '[ERREUR] Le processus Nginx s’est terminé avec une erreur.' >&2
    exit 4
fi
