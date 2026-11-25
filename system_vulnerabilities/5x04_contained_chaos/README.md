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

Cette image contient volontairement des identifiants de démonstration et des
configurations dangereuses. Ne pas l'utiliser hors du laboratoire.
