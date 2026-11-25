# Contained Chaos

Ce dossier regroupe les exercices Holberton sur la sécurisation des images et
des conteneurs Docker. Le parcours commence par l'analyse des défauts d'un
Dockerfile vulnérable, puis aborde la réduction des privilèges, la gestion des
secrets, les dépendances et les contrôles d'exécution.

## Tâches réalisées

1. `0-insecure_analysis.md` recense les risques présents dans le Dockerfile
   DevStream, explique leur impact et donne des scénarios d'exploitation.
2. `1-build_vulnerable.sh` crée l'application Flask et son Dockerfile de labo,
   construit l'image `devstream-vulnerable:latest` et affiche sa taille, son
   utilisateur configuré et les variables de base de données intégrées. Le
   build nécessite un daemon Docker actif.
3. `2-inspect_history.sh` affiche l'historique des couches d'une image Docker
   et retrouve les mots de passe inscrits dans les instructions `RUN` et `ENV`.
4. `3-docker_bench.sh` lance Docker Bench Security pour auditer la configuration
   Docker de l'hôte et les images locales, puis conserve la sortie complète dans
   `docker-bench-report.txt`.
5. `Dockerfile` utilise `python:3.11-slim`, crée `appuser` avec l'UID 1000 et
   démarre l'application depuis `/app` sans privilèges root. Vérification prévue :
   `docker build -t devstream-nonroot:v1 -f Dockerfile .`, puis
   `docker run --rm devstream-nonroot:v1 id`.

Cette image contient volontairement des identifiants de démonstration et des
configurations dangereuses. Ne pas l'utiliser hors du laboratoire.
