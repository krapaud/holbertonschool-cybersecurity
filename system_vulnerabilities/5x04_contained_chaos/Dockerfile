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
LABEL org.opencontainers.image.title="Secure Python Development Environment" \
      org.opencontainers.image.description="Python 3.11 development image with least-privilege defaults" \
      org.opencontainers.image.version="1.0" \
      org.opencontainers.image.vendor="NovaTech Solutions"

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 1000 --user-group appuser
WORKDIR /app
RUN mkdir -p /app/logs && chown appuser:appuser /app/logs
COPY --from=builder /wheels /wheels
COPY requirements.txt .
RUN pip install --no-cache-dir --no-index --find-links=/wheels \
    -r requirements.txt \
    && rm -rf /wheels
COPY --chown=appuser:appuser app.py ./app.py

# Outils utiles au développement, installés dans l'image de l'exercice.
RUN python -m pip install --no-cache-dir pylint black pytest mypy \
    && python -m venv /opt/venv \
    && useradd --create-home --uid 1000 --user-group devuser \
    && mkdir -p /workspace \
    && chown devuser:devuser /workspace \
    && chmod 0755 /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"
WORKDIR /workspace

# Les secrets sont fournis à l'exécution, jamais dans une couche de build.
# Exemple : docker run -e DB_HOST=... -e DB_USER=... -e DB_PASSWORD=...
ENV APP_LOG_FILE=/app/logs/app.log
USER devuser
EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1
CMD ["python", "app.py"]
