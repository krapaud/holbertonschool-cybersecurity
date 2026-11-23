# Identity Fortress

Ce dossier regroupe les exercices Holberton sur la sécurisation des comptes
Linux et de l’authentification. Le projet aborde PAM, les règles de mots de
passe, les tentatives répétées, les clés SSH et le TOTP.

## Parcours

Les premières tâches servent à comprendre et auditer l’état actuel.
Les tâches suivantes ajoutent les protections progressivement. Sauvegarder les
changements PAM et SSH, puis les tester depuis une deuxième session.

## Tâches réalisées

1. `1-pam_audit.sh` audite les réglages PAM, le verrouillage des comptes et
   l’authentification SSH.
2. `2-password_complexity.sh` configure `pam_pwquality` et vérifie le rejet de
   mots de passe faibles.
3. `3-test_complexity.sh` teste cinq exemples avec `passwd` sur un compte
   temporaire, supprimé à la fin du script.
4. `4-password_history.sh` configure `pam_pwhistory` pour retenir cinq mots de
   passe et protège `/etc/security/opasswd`.
5. `5-password_aging.sh` configure les valeurs par défaut dans
   `/etc/login.defs` et applique les limites aux comptes interactifs existants.

Exécuter les scripts qui modifient le système avec `sudo` dans la VM de
laboratoire. Vérifier la syntaxe Bash avec `bash -n`.

## Vérifier les scripts

Les scripts Bash commencent par `#!/bin/bash`, sont exécutables et finissent
par une nouvelle ligne. Vérifier leur syntaxe avec `bash -n nom_du_script.sh`.
Tester les changements d’authentification uniquement dans la VM dédiée.
