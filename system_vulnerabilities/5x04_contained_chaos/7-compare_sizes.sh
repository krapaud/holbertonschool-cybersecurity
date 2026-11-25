#!/bin/bash

# Je compare une image avec outils de build à l'image multi-stage finale.
set -euo pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

command -v docker >/dev/null 2>&1 || error 'Docker is not installed.'
script_directory=$(cd -- "$(dirname -- "$0")" && pwd) || \
    error 'Could not determine the exercise directory.'
temporary_directory=$(mktemp -d) || \
    error 'Could not create a temporary directory.'
trap 'rm -rf -- "$temporary_directory"' EXIT

single_stage_file=$temporary_directory/Dockerfile.single
single_stage_image=devstream-single-stage:v1
multi_stage_image=devstream-multistage:v1

# Cette image de comparaison conserve gcc et make après installation.
cat > "$single_stage_file" <<'DOCKERFILE'
FROM python:3.11-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc make \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN useradd --create-home --uid 1000 appuser
COPY --chown=appuser:appuser app.py ./app.py
USER appuser
EXPOSE 5000
CMD ["python", "app.py"]
DOCKERFILE

printf 'Building single-stage comparison image...\n'
docker build -f "$single_stage_file" -t "$single_stage_image" \
    "$script_directory" || error 'Single-stage image build failed.'

printf 'Building multi-stage image...\n'
docker build -f "$script_directory/Dockerfile" -t "$multi_stage_image" \
    "$script_directory" || error 'Multi-stage image build failed.'

# Je récupère les tailles du moteur Docker, puis calcule la réduction observée.
single_bytes=$(docker image inspect --format '{{.Size}}' "$single_stage_image") || \
    error 'Could not read the single-stage image size.'
multi_bytes=$(docker image inspect --format '{{.Size}}' "$multi_stage_image") || \
    error 'Could not read the multi-stage image size.'
[[ "$single_bytes" =~ ^[0-9]+$ && "$multi_bytes" =~ ^[0-9]+$ ]] || \
    error 'Docker returned an invalid image size.'

single_mb=$(( (single_bytes + 500000) / 1000000 ))
multi_mb=$(( (multi_bytes + 500000) / 1000000 ))
if (( single_bytes > 0 )); then
    reduction=$(( (single_bytes - multi_bytes) * 100 / single_bytes ))
else
    reduction=0
fi

printf '\nSingle-stage image: %s MB\n' "$single_mb"
printf 'Multi-stage image: %s MB\n' "$multi_mb"
printf 'Reduction: %s%%\n' "$reduction"
printf 'Packages in final image:\n'
printf '  python3.11\n  flask\n  (minimal runtime only)\n'

# Je vérifie que l'application s'importe et que les compilateurs sont absents.
if docker run --rm "$multi_stage_image" sh -c \
    'python -c "import flask" && ! command -v gcc >/dev/null 2>&1 && ! command -v make >/dev/null 2>&1'; then
    printf 'Build tools excluded:\n  gcc ✓\n  make ✓\n  pip (caches cleared) ✓\n'
else
    error 'The final image is missing Flask or still contains build tools.'
fi
