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
6. `6-force_password_change.sh` expire les mots de passe des comptes fournis
   et vérifie qu’ils devront le changer à leur prochaine connexion.
7. `8-configure_faillock.sh` configure le verrouillage après cinq échecs,
   avec une fenêtre de 15 minutes, un déverrouillage après 15 minutes et
   remet le compteur à zéro après une authentification réussie.
8. `9-faillock_manage.sh` affiche les comptes verrouillés, les échecs récents
   d’un utilisateur et permet à l’administrateur de réinitialiser son compteur.
9. `10-configure_fail2ban.sh` installe Fail2ban et configure le jail SSH pour
   bannir une adresse après cinq échecs en dix minutes pendant une heure.
10. `11-fail2ban_manage.sh` affiche l’état des jails, liste les IP bannies et
    permet de débannir une adresse de la jail SSH.
11. `12-generate_ssh_key.sh` crée une paire ED25519, recommande une phrase de
    passe et affiche l’empreinte et la clé publique.
12. `13-deploy_ssh_key.sh` valide une clé publique et l’ajoute sans doublon
    au fichier `authorized_keys` de l’utilisateur cible.
13. `14-disable_password_auth.sh` exige une connexion locale par clé avant de
    désactiver les mots de passe SSH et restaure la configuration si le test
    après rechargement échoue.
14. `16-install_google_auth.sh` installe `libpam-google-authenticator` si
    nécessaire et vérifie l'emplacement du module PAM.

Exécuter les scripts qui modifient le système avec `sudo` dans la VM de
laboratoire. Vérifier la syntaxe Bash avec `bash -n`.

## Vérifier les scripts

Les scripts Bash commencent par `#!/bin/bash`, sont exécutables et finissent
par une nouvelle ligne. Vérifier leur syntaxe avec `bash -n nom_du_script.sh`.
Tester les changements d’authentification uniquement dans la VM dédiée.
