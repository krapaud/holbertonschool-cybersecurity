#!/bin/bash

# Je démarre le conteneur avec des plafonds de mémoire, CPU et processus.
set -euo pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

command -v docker >/dev/null 2>&1 || error 'Docker is not installed.'
script_directory=$(cd -- "$(dirname -- "$0")" && pwd) || \
    error 'Could not determine the exercise directory.'

image_name=devstream-limited:v1
container_name=devstream-limited
if docker container inspect "$container_name" >/dev/null 2>&1; then
    error "Container $container_name already exists. Remove it before retrying."
fi

# Je reconstruis l'image pour utiliser le code et les dépendances du dossier.
docker build -q -t "$image_name" "$script_directory" >/dev/null || \
    error 'Could not build the limited container image.'

printf 'Applying limits:\n'
printf '  --memory=256m (max 256MB RAM)\n'
printf '  --memory-swap=256m (no swap)\n'
printf '  --cpus=0.5 (max 50%% of one CPU)\n'
printf '  --pids-limit=50 (max 50 processes)\n'
docker run -d --name "$container_name" \
    --memory=256m \
    --memory-swap=256m \
    --cpus=0.5 \
    --pids-limit=50 \
    "$image_name" >/dev/null || error 'Could not start the limited container.'
printf 'Container started: %s\n' "$container_name"

# Je contrôle les valeurs configurées par le moteur Docker, pas seulement les options saisies.
memory_limit=$(docker inspect --format '{{.HostConfig.Memory}}' "$container_name") || \
    error 'Could not inspect the container memory limit.'
memory_swap=$(docker inspect --format '{{.HostConfig.MemorySwap}}' "$container_name") || \
    error 'Could not inspect the container memory swap limit.'
cpu_limit=$(docker inspect --format '{{.HostConfig.NanoCpus}}' "$container_name") || \
    error 'Could not inspect the container CPU limit.'
pids_limit=$(docker inspect --format '{{.HostConfig.PidsLimit}}' "$container_name") || \
    error 'Could not inspect the container process limit.'

expected_memory=268435456
expected_cpu=500000000
if [ "$memory_limit" != "$expected_memory" ] || \
    [ "$memory_swap" != "$expected_memory" ] || \
    [ "$cpu_limit" != "$expected_cpu" ] || \
    [ "$pids_limit" != 50 ]; then
    error 'The effective container resource limits do not match the requested values.'
fi

printf 'Verification:\n'
printf '  Memory limit: 256MB\n'
printf '  CPU limit: 0.5 cores\n'
printf '  PID limit: 50\n'
printf 'Resource limits active.\n'
printf 'Container cannot exhaust host resources.\n'
