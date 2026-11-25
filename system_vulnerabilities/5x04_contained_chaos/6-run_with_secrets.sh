#!/bin/bash

# Je demande les secrets au lancement et ne les place pas dans l'image.
set -euo pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

command -v docker >/dev/null 2>&1 || error 'Docker is not installed.'
docker image inspect devstream-nosecrets:v1 >/dev/null 2>&1 || \
    error 'Image devstream-nosecrets:v1 not found. Build it first.'

printf '=== Run Container with Runtime Secrets ===\n\n'
read -r -p 'Database host: ' DB_HOST
read -r -p 'Database user: ' DB_USER
read -r -s -p 'Database password: ' DB_PASSWORD
printf '\n'

[[ -n "$DB_HOST" && -n "$DB_USER" && -n "$DB_PASSWORD" ]] || \
    error 'Database host, user, and password are required.'

# Ces variables ne sont transmises qu'au conteneur lancé, jamais au build.
export DB_HOST DB_USER DB_PASSWORD
printf 'Starting devstream-nosecrets:v1 with runtime environment variables...\n'
docker run --rm -p 5000:5000 -e "DB_HOST=$DB_HOST" -e "DB_USER=$DB_USER" -e "DB_PASSWORD=$DB_PASSWORD" devstream-nosecrets:v1
