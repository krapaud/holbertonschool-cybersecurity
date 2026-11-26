#!/bin/bash

# Je reconstruis l'image, puis je vérifie les écritures permises avec des tmpfs.
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
image_name=devstream-readonly:v1
container_name=devstream-readonly
container_created=0

# Si une vérification échoue, je retire seulement le conteneur créé ici.
cleanup_failed_run()
{
    local exit_status=$?
    if [ "$exit_status" -ne 0 ] && [ "$container_created" -eq 1 ]; then
        docker rm -f "$container_name" >/dev/null 2>&1 || true
    fi
    return "$exit_status"
}
trap cleanup_failed_run EXIT

if docker container inspect "$container_name" >/dev/null 2>&1; then
    error "Container $container_name already exists. Remove it before retrying."
fi

# Je construis l'image à jour pour inclure /app/logs et la configuration Flask.
docker build -q -t "$image_name" "$script_directory" >/dev/null || \
    error 'Could not build the read-only test image.'

printf 'Starting container with:\n'
printf '  --read-only\n'
printf '  --tmpfs /tmp (for temporary files)\n'
printf '  --tmpfs /app/logs (for application logs)\n'
docker run -d --name "$container_name" --read-only \
    --tmpfs /tmp:rw,noexec,nosuid,nodev,size=64m \
    --tmpfs /app/logs:rw,noexec,nosuid,nodev,size=16m,uid=1000,gid=1000,mode=0750 \
    "$image_name" >/dev/null || error 'Could not start the read-only container.'
container_created=1

# J'attends que Flask réponde avant de tester le système de fichiers.
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

# Je teste en root pour prouver que le système racine lui-même est en lecture seule.
probe_id="$$-$RANDOM"
for blocked_path in "/etc/readonly-probe-$probe_id" "/app/readonly-probe-$probe_id"; do
    if docker exec --user 0 "$container_name" python -c \
        'import pathlib, sys; pathlib.Path(sys.argv[1]).write_text("probe")' \
        "$blocked_path" >/dev/null 2>&1; then
        error "Write unexpectedly succeeded at $blocked_path."
    fi
done
printf 'Verification:\n'
printf '  Attempt to write to /etc: BLOCKED\n'
printf '  Attempt to write to /app: BLOCKED\n'

# /tmp est temporaire; le tmpfs des logs appartient à appuser (UID 1000).
docker exec "$container_name" python -c \
    'from pathlib import Path; p=Path("/tmp/readonly-probe"); p.write_text("ok"); p.unlink()' \
    >/dev/null || error 'Writing to /tmp failed.'
printf '  Attempt to write to /tmp: ALLOWED\n'

# L'appel /health a déclenché une vraie ligne de journal dans le tmpfs /app/logs.
if docker exec "$container_name" python -c \
    'from pathlib import Path; p=Path("/app/logs/app.log"); assert p.is_file() and p.stat().st_size > 0'; then
    printf '  Application logging: WORKING\n'
else
    error 'Application log file was not written to /app/logs.'
fi

printf 'Root filesystem: READ-ONLY\n'
printf 'Attackers cannot modify system files or drop tools.\n'
