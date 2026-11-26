#!/bin/bash

# Je lance l'application avec les protections Docker recommandées, puis je
# vérifie les options effectives depuis la configuration et /proc/1/status.
set -euo pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

command -v docker >/dev/null 2>&1 || error 'Docker is not installed.'
command -v awk >/dev/null 2>&1 || error 'awk is not installed.'
command -v sleep >/dev/null 2>&1 || error 'sleep is not installed.'
script_directory=$(cd -- "$(dirname -- "$0")" && pwd) || \
    error 'Could not determine the exercise directory.'

image_name=devstream-maxsecure:v1
container_name=devstream-maxsecure
if docker container inspect "$container_name" >/dev/null 2>&1; then
    error "Container $container_name already exists. Remove it before retrying."
fi

# Je reconstruis l'image à partir des fichiers de l'exercice.
docker build -q -t "$image_name" "$script_directory" >/dev/null || \
    error 'Could not build the secure container image.'

printf 'Security options applied:\n'
printf '  --security-opt=no-new-privileges:true\n'
printf '    (Process cannot gain new privileges via setuid, etc.)\n'
printf '  --security-opt=seccomp=default\n'
printf '    (Syscall filtering enabled)\n'
printf 'Additional hardening:\n'
printf '  --cap-drop=ALL\n'
printf '  --read-only\n'
printf '  --user=appuser\n'
docker run -d --name "$container_name" \
    --security-opt=no-new-privileges:true \
    --security-opt=seccomp=default \
    --cap-drop=ALL \
    --read-only \
    --user=appuser \
    --tmpfs /tmp:rw,noexec,nosuid,nodev,size=64m \
    --tmpfs /app/logs:rw,noexec,nosuid,nodev,size=16m,uid=1000,gid=1000,mode=0750 \
    "$image_name" >/dev/null || error 'Could not start the hardened container.'
printf 'Container started with maximum hardening.\n'

# J'attends que le service soit joignable avant de confirmer les protections.
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
[ "$application_ready" -eq 1 ] || error 'The application did not respond on /health.'

# Je lis les protections du processus principal, pas seulement les options saisies.
process_status=$(docker exec "$container_name" cat /proc/1/status) || \
    error 'Could not read the main process status.'
no_new_privs=$(printf '%s\n' "$process_status" | awk '$1 == "NoNewPrivs:" { print $2 }')
seccomp_mode=$(printf '%s\n' "$process_status" | awk '$1 == "Seccomp:" { print $2 }')
process_user=$(docker exec "$container_name" id -un) || \
    error 'Could not identify the container process user.'

security_options=$(docker inspect --format '{{json .HostConfig.SecurityOpt}}' \
    "$container_name") || error 'Could not inspect the security options.'
case "$security_options" in
    *no-new-privileges:true*) ;;
    *) error 'no-new-privileges is not active in the container configuration.' ;;
esac
case "$security_options" in
    *seccomp=default*) ;;
    *) error 'The default seccomp profile is not active in the container configuration.' ;;
esac
[ "$no_new_privs" = 1 ] || error 'The process can still gain new privileges.'
[ "$seccomp_mode" = 2 ] || error 'Seccomp filtering is not active for the process.'
[ "$process_user" = appuser ] || error "Unexpected container user: $process_user"

printf 'Security verification:\n'
printf '  New privileges: BLOCKED\n'
printf '  Seccomp: ENABLED\n'
printf '  Root access: NONE\n'
