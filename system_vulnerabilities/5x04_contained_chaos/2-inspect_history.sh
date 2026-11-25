#!/bin/bash

# Je lis l'historique Docker et repère les secrets conservés dans ses couches.

set -euo pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

if [ "$#" -ne 1 ]; then
    printf 'Usage: %s IMAGE_NAME\n' "${0##*/}" >&2
    exit 2
fi

for command_name in awk docker grep mktemp rm sed; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done

image_name=$1
temporary_directory=$(mktemp -d) || \
    error 'Could not create a temporary directory.'
trap 'rm -rf -- "$temporary_directory"' EXIT
history_file=$temporary_directory/history

docker image inspect "$image_name" >/dev/null 2>&1 || \
    error "Docker image not found: $image_name"

if ! docker history --no-trunc --format '{{.CreatedBy}}' \
    "$image_name" > "$history_file"; then
    error "Could not read Docker history for $image_name."
fi

printf 'Image: %s\n' "$image_name"
printf 'Layer History:\n'

# Docker renvoie les couches de la plus récente à la plus ancienne.
layer_number=0
while IFS= read -r created_by; do
    [ -n "$created_by" ] || continue
    layer_number=$((layer_number + 1))
    case "$created_by" in
        *chpasswd*)
            printf '  Layer %s: RUN echo root password | chpasswd  <-- PASSWORD EXPOSED\n' \
                "$layer_number"
            ;;
        *DB_HOST=*)
            value=${created_by##*DB_HOST=}
            value=${value%%[[:space:]]*}
            printf '  Layer %s: ENV DB_HOST=%s\n' "$layer_number" "$value"
            ;;
        *DB_USER=*)
            value=${created_by##*DB_USER=}
            value=${value%%[[:space:]]*}
            printf '  Layer %s: ENV DB_USER=%s\n' "$layer_number" "$value"
            ;;
        *DB_PASSWORD=*)
            value=${created_by##*DB_PASSWORD=}
            value=${value%%[[:space:]]*}
            printf '  Layer %s: ENV DB_PASSWORD=%s  <-- SECRET EXPOSED\n' \
                "$layer_number" "$value"
            ;;
        *'apt-get update'*)
            printf '  Layer %s: RUN apt-get update...\n' "$layer_number"
            ;;
        *)
            printf '  Layer %s: %s\n' "$layer_number" "$created_by"
            ;;
    esac
done < <(awk '{ rows[NR] = $0 } END { for (i = NR; i > 0; i--) print rows[i] }' \
    "$history_file")

# Les valeurs sont extraites des commandes présentes dans l'historique.
root_password=$(grep -m 1 'chpasswd' "$history_file" | \
    sed -n "s/.*root:\\([^'[:space:]]*\\).*/\\1/p" || true)
database_password=$(grep -m 1 'DB_PASSWORD=' "$history_file" | \
    sed -n 's/.*DB_PASSWORD=\([^[:space:]]*\).*/\1/p' || true)

[ -n "$root_password" ] || \
    error 'The root password was not found in Docker history.'
[ -n "$database_password" ] || \
    error 'The database password was not found in Docker history.'

printf '\nExtracting secrets from history...\n'
printf '  Root password: %s\n' "$root_password"
printf '  DB Password: %s\n' "$database_password"
printf 'CRITICAL: All ENV and RUN commands are permanently\n'
printf 'visible in image layers. Never put secrets here!\n'
