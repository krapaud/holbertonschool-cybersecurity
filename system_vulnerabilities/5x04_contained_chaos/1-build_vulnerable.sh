#!/bin/bash

# Je crée l'application de labo, construis l'image vulnérable et inspecte ses
# informations sans lancer le conteneur.

set -euo pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

for command_name in awk docker; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done

script_directory=$(cd -- "$(dirname -- "$0")" && pwd) || \
    error 'Could not find the exercise directory.'
image_name=devstream-vulnerable:latest

printf 'Creating application files...\n'

cat > "$script_directory/app.py" <<'PYTHON'
from flask import Flask
import os

app = Flask(__name__)


@app.route('/')
def hello():
    return f"Hello from DevStream! DB: {os.environ.get('DB_HOST', 'unknown')}"


@app.route('/health')
def health():
    return "OK", 200


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
PYTHON
printf '  app.py: Created\n'

cat > "$script_directory/requirements.txt" <<'REQUIREMENTS'
flask==3.0.0
REQUIREMENTS
printf '  requirements.txt: Created\n'

# Ubuntu recent utilise pip en mode environnement géré; cette option permet
# de reproduire le Dockerfile du cours et reste volontairement peu sûre.
cat > "$script_directory/Dockerfile" <<'DOCKERFILE'
# DevStream's "production" Dockerfile
# DO NOT USE IN PRODUCTION (but they did...)

FROM ubuntu:latest

# Install everything we might need
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    curl \
    wget \
    vim \
    net-tools \
    iputils-ping \
    gcc \
    make \
    sudo

# Set root password (for debugging)
RUN echo 'root:devstream123' | chpasswd

# Database credentials
ENV DB_HOST=prod-db.devstream.internal
ENV DB_USER=admin
ENV DB_PASSWORD=Sup3rS3cr3t!Pr0d

# Copy application
WORKDIR /app
COPY . /app

# Install Python dependencies
ENV PIP_BREAK_SYSTEM_PACKAGES=1
RUN pip3 install -r requirements.txt

# Run as root because it's easier
EXPOSE 5000

CMD ["python3", "app.py"]
DOCKERFILE
printf '  Dockerfile: Created\n'

if ! docker info >/dev/null 2>&1; then
    error 'Docker is unavailable. Start the Docker daemon and run this script again.'
fi

printf 'Building image...\n'
if ! docker build --tag "$image_name" "$script_directory"; then
    error 'Docker image build failed.'
fi
printf '  Image: %s\n' "$image_name"
printf '  Build: SUCCESS\n'

# Je lis les métadonnées réelles de l'image au lieu d'inventer sa taille.
image_size=$(docker image inspect --format '{{.Size}}' "$image_name") || \
    error 'Could not read image size.'
image_user=$(docker image inspect --format \
    '{{if .Config.User}}{{.Config.User}}{{else}}root{{end}}' "$image_name") || \
    error 'Could not read the configured image user.'
image_environment=$(docker image inspect --format \
    '{{range .Config.Env}}{{println .}}{{end}}' "$image_name") || \
    error 'Could not read image environment variables.'

image_size_mb=$(awk -v bytes="$image_size" \
    'BEGIN { printf "%.0f MB", bytes / 1000000 }')
printf '\nImage Analysis:\n'
printf '  Size: %s\n' "$image_size_mb"
printf '  Base: ubuntu:latest\n'
if [ "$image_user" = root ]; then
    printf '  User: root (UID 0)\n'
else
    printf '  User: %s\n' "$image_user"
fi

printf '\nEnvironment Variables (EXPOSED SECRETS):\n'
for variable_name in DB_HOST DB_USER DB_PASSWORD; do
    variable_value=$(printf '%s\n' "$image_environment" | \
        awk -v prefix="$variable_name=" \
            'index($0, prefix) == 1 { print substr($0, length(prefix) + 1); exit }')
    [ -n "$variable_value" ] || \
        error "Expected image variable not found: $variable_name"
    printf '  %s=%s\n' "$variable_name" "$variable_value"
done

printf '\nWARNING: This image contains hardcoded credentials!\n'
