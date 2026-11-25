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
6. `6-run_with_secrets.sh` demande les identifiants de base de données au
   lancement et les transmet à `devstream-nosecrets:v1` avec `docker run -e`.
   Les secrets ne sont pas intégrés au Dockerfile ni à l'image. En production,
   privilégier un fichier de secrets monté ou un gestionnaire de secrets.
7. `7-compare_sizes.sh` construit une image de comparaison avec `gcc` et `make`
   conservés, puis l'image multi-stage. Il affiche les tailles réelles, calcule
   la réduction et vérifie que Flask fonctionne sans les outils de compilation.

L'image vulnérable construite par l'exercice 1 contient volontairement des
identifiants de démonstration et des configurations dangereuses. Ne pas
l'utiliser hors du laboratoire. Le Dockerfile courant ne contient pas ces
identifiants.
