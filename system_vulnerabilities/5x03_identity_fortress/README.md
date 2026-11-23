# Identity Fortress

Ce dossier regroupe les exercices Holberton sur la sécurisation des comptes
Linux et de l’authentification. Le projet traite de PAM, des règles de mots de
passe, de la protection contre les tentatives répétées, des clés SSH et du
TOTP.

## Parcours

Les premières tâches servent à comprendre et auditer l’état actuel. Les tâches
suivantes ajoutent les protections progressivement. Les changements PAM et SSH
doivent être sauvegardés et testés depuis une deuxième session avant de fermer
la session de travail.

## Vérifier les scripts

Les scripts Bash commencent par `#!/bin/bash`, sont exécutables et se terminent
par une nouvelle ligne. Vérifier leur syntaxe avec `bash -n nom_du_script.sh`.
Les changements d’authentification doivent être testés uniquement dans la VM de
laboratoire.
