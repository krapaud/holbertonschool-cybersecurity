#!/bin/bash
# Je prépare le conteneur, puis je garde Nginx au premier plan.
set -uo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo '[ERREUR] Lance ce script en root dans le conteneur.' >&2
    exit 1
fi

for tool in curl grep nginx service sleep sshd; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[ERREUR] Commande manquante : $tool" >&2
        exit 1
    fi
done

# Je lance les deux scripts de préparation et je garde leur code d'erreur.
if /opt/hardened-shield/scripts/init-hardening.sh; then
    echo '[RÉUSSI] Réglages système appliqués.'
else
    result=$?
    echo '[ERREUR] Le durcissement système a échoué.' >&2
    exit "$result"
fi

if /opt/hardened-shield/scripts/init-identity.sh; then
    echo '[RÉUSSI] Réglages d’identité appliqués.'
else
    result=$?
    echo '[ERREUR] Le durcissement de l’identité a échoué.' >&2
    exit "$result"
fi

# Je valide la configuration avant de démarrer les services.
if ! nginx -t >/dev/null 2>&1; then
    echo '[ERREUR] La configuration Nginx est invalide.' >&2
    exit 2
fi
if ! sshd -t >/dev/null 2>&1; then
    echo '[ERREUR] La configuration SSH est invalide.' >&2
    exit 2
fi

echo '[INFO] Démarrage de SSH...'
if ! service ssh start >/dev/null 2>&1; then
    echo '[ERREUR] Le service SSH n’a pas démarré.' >&2
    exit 3
fi

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
