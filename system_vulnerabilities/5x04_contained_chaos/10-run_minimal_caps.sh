#!/bin/bash

# Je lance l'image avec toutes les capacités Linux supprimées, puis je vérifie
# les capacités effectives du processus et la réponse HTTP de l'application.
set -euo pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

command -v docker >/dev/null 2>&1 || error 'Docker is not installed.'
command -v awk >/dev/null 2>&1 || error 'awk is not installed.'
command -v sleep >/dev/null 2>&1 || error 'sleep is not installed.'

image_name=${IMAGE_NAME:-devstream-health:v1}
container_name=devstream-secure
docker image inspect "$image_name" >/dev/null 2>&1 || \
    error "Image $image_name not found. Build it first or set IMAGE_NAME."
if docker container inspect "$container_name" >/dev/null 2>&1; then
    error "Container $container_name already exists. Remove it before retrying."
fi

printf 'Dropping all capabilities...\n'
printf 'Adding back only required capabilities:\n'
printf '  (none needed for this application)\n'
printf 'Starting container...\n'
docker run -d --name "$container_name" --cap-drop ALL \
    -p 127.0.0.1:5000:5000 "$image_name" >/dev/null || \
    error 'Could not start the container.'
printf '  Container: %s\n' "$container_name"
printf '  Capabilities: NONE\n'

# Le processus démarre en arrière-plan; j'attends que /health réponde.
application_ready=0
for attempt in {1..20}; do
    if docker exec "$container_name" python -c \
        'import urllib.request; urllib.request.urlopen("http://127.0.0.1:5000/health", timeout=2)' \
        >/dev/null 2>&1; then
        application_ready=1
        break
    fi
    sleep 1
done
[ "$application_ready" -eq 1 ] || \
    error 'The application did not respond on /health.'

# Je lis CapPrm et CapEff dans le statut réel du processus PID 1.
printf 'Verification:\n'
printf '  $ docker exec %s cat /proc/1/status | grep Cap\n' "$container_name"
capability_status=$(docker exec "$container_name" sh -c \
    'cat /proc/1/status | grep -E "^Cap(Prm|Eff):"') || \
    error 'Could not read process capability status.'
printf '%s\n' "$capability_status"
cap_prm=$(printf '%s\n' "$capability_status" | awk '$1 == "CapPrm:" { print $2 }')
cap_eff=$(printf '%s\n' "$capability_status" | awk '$1 == "CapEff:" { print $2 }')
zero_caps=0000000000000000
if [ "$cap_prm" != "$zero_caps" ] || [ "$cap_eff" != "$zero_caps" ]; then
    error 'The container still has permitted or effective capabilities.'
fi

printf 'Application status: Running normally ✓\n'
printf 'The container has ZERO elevated capabilities.\n'
printf "Even if compromised, the attacker's abilities are limited.\n"
