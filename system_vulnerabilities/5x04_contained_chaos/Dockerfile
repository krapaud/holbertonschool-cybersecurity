# Première étape : je prépare les dépendances dans un environnement de build.
FROM python:3.11-slim AS builder
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    make \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /build
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

# Deuxième étape : l'image finale ne contient que Python et l'application.
FROM python:3.11-slim AS runtime
RUN useradd --create-home --uid 1000 appuser
WORKDIR /app
COPY --from=builder /wheels /wheels
COPY requirements.txt .
RUN pip install --no-cache-dir --no-index --find-links=/wheels \
    -r requirements.txt \
    && rm -rf /wheels
COPY --chown=appuser:appuser app.py ./app.py

# Les secrets sont fournis à l'exécution, jamais dans une couche de build.
# Exemple : docker run -e DB_HOST=... -e DB_USER=... -e DB_PASSWORD=...
USER appuser
EXPOSE 5000
CMD ["python", "app.py"]
