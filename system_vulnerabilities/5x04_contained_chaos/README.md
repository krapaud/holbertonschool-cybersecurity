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
5. `Dockerfile` utilise `python:3.11-slim`, crée `appuser` (UID/GID 1000) et
   démarre l'application sans privilèges root. L'exercice 15 y ajoute aussi
   `devuser` (UID/GID 1000), pip, venv, pylint, black, pytest et mypy; l'image
   finale utilise `devuser`. Vérifier avec `docker build -t secure-python-dev:v1
   -f Dockerfile .`, puis `docker run --rm secure-python-dev:v1 id`.
6. `6-run_with_secrets.sh` demande les identifiants de base de données au
   lancement et les transmet à `devstream-nosecrets:v1` avec `docker run -e`.
   Les secrets ne sont pas intégrés au Dockerfile ni à l'image. En production,
   privilégier un fichier de secrets monté ou un gestionnaire de secrets.
7. `7-compare_sizes.sh` construit une image de comparaison avec `gcc` et `make`
   conservés, puis l'image multi-stage. Il affiche les tailles réelles, calcule
   la réduction et vérifie que Flask fonctionne sans les outils de compilation.
8. Le `Dockerfile` installe `curl` pour le contrôle de santé et vérifie
   `/health` toutes les 30 secondes, avec un délai de 10 secondes et trois
   tentatives avant de déclarer le conteneur unhealthy.
9. `10-run_minimal_caps.sh` lance `devstream-health:v1` avec `--cap-drop ALL`,
   vérifie que `CapPrm` et `CapEff` sont nuls et attend une réponse valide sur
   `/health`. Le conteneur reste lancé après la vérification; définir
   `IMAGE_NAME` permet de choisir une autre image compatible.
10. `11-run_readonly.sh` construit une image de vérification, démarre le
    conteneur avec `--read-only` et monte `/tmp` ainsi que `/app/logs` en tmpfs.
    Il vérifie les chemins bloqués, l'écriture temporaire et le fichier de log.
11. `12-run_limited.sh` démarre `devstream-limited` avec 256 Mo de mémoire,
    sans swap, 0,5 CPU et un plafond de 50 processus. Il confirme les valeurs
    effectives avec `docker inspect`.
12. `13-run_secure.sh` lance l'application avec `no-new-privileges`, seccomp,
    zéro capacité, un système de fichiers en lecture seule et l'utilisateur
    `appuser`. Il vérifie l'état `NoNewPrivs`, le mode seccomp et l'utilisateur.
13. `14-design_document.md` décrit l'image Python, les outils de développement,
    l'utilisateur non-root, les montages, les mesures de sécurité et le
    workflow destiné aux développeurs.
14. `15-Dockerfile.securedev` construit l'environnement Python 3.11 avec pip,
    venv, pylint, black, pytest et mypy. Il utilise `devuser` (UID/GID 1000),
    des labels OCI, un contrôle de santé et n'intègre aucun secret.
    Vérifications : `docker build -t secure-python-dev:v1 -f
    15-Dockerfile.securedev .`, puis lancer l'image avec `id`, `python
    --version` et `pylint --version`.

L'image vulnérable construite par l'exercice 1 contient volontairement des
identifiants de démonstration et des configurations dangereuses. Ne pas
l'utiliser hors du laboratoire. Le Dockerfile courant ne contient pas ces
identifiants.
