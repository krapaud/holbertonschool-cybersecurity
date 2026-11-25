# Image Python légère pour l'application DevStream.
FROM python:3.11-slim

# Je crée un compte sans privilèges pour exécuter l'application.
RUN useradd --create-home --uid 1000 appuser

# L'application et ses dépendances sont installées dans /app.
WORKDIR /app
COPY --chown=appuser:appuser app.py requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Le processus du conteneur s'exécute avec ce compte non-root.
USER appuser

EXPOSE 5000
CMD ["python", "app.py"]
