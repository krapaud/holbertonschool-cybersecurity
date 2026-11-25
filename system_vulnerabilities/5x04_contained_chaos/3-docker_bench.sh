#!/bin/bash

# Je lance Docker Bench et garde les résultats dans un fichier du labo.

set -euo pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

if [ "$#" -gt 1 ]; then
    printf 'Usage: %s [IMAGE_NAME]\n' "${0##*/}" >&2
    exit 2
fi

for command_name in docker tee; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done

script_directory=$(cd -- "$(dirname -- "$0")" && pwd) || \
    error 'Could not find the exercise directory.'
image_name=${1:-devstream-vulnerable:latest}
report_file=$script_directory/docker-bench-report.txt

if ! docker info >/dev/null 2>&1; then
    error 'Docker daemon is unavailable. Start Docker and run this script again.'
fi

docker image inspect "$image_name" >/dev/null 2>&1 || \
    error "Image not found: $image_name. Build it before running Docker Bench."

printf 'Running docker-bench-security for %s...\n' "$image_name"
printf 'The benchmark checks the Docker host and its local images/containers.\n\n'

# L'image officielle Docker Bench a besoin d'accéder aux contrôles de l'hôte.
if ! docker run --rm \
    --net host \
    --pid host \
    --userns host \
    --cap-add audit_control \
    -e DOCKER_CONTENT_TRUST="${DOCKER_CONTENT_TRUST:-}" \
    -v /etc:/etc:ro \
    -v /usr/bin/containerd:/usr/bin/containerd:ro \
    -v /usr/bin/runc:/usr/bin/runc:ro \
    -v /usr/lib/systemd:/usr/lib/systemd:ro \
    -v /var/lib:/var/lib:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    docker/docker-bench-security 2>&1 | tee "$report_file"; then
    error "Docker Bench failed. Check the output and $report_file."
fi

printf '\nFull report saved to: %s\n' "$report_file"
