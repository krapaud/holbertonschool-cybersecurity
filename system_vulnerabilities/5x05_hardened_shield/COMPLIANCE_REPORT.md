# Rapport de conformité technique

**Projet :** The Hardened Shield  
**Date du rapport :** 27 novembre 2026  
**Référentiel :** contrôles définis dans le projet 5x05

## 1. Résumé exécutif

L'image Ubuntu 20.04 démarre avec Nginx et SSH. Les règles PAM, les
permissions système et plusieurs protections Docker ont été vérifiées. Le
test du conteneur a obtenu `41/55`, soit `75%`, avec le résultat `FAIL`.

Le système de fichiers et les contrôles d'identité testés ont tous réussi.
L'audit relève encore des risques concernant les paramètres noyau fournis par
l'hôte, Fail2ban, la racine du conteneur en lecture-écriture et l'absence de
configuration TOTP active. La solution n'est donc pas approuvée pour la
production à la date de ce rapport.

## 2. Périmètre

Cette vérification porte sur les fichiers de
`system_vulnerabilities/5x05_hardened_shield`, l'image construite sur
Ubuntu 20.04 et son lancement avec les restrictions prévues dans Compose.
Elle couvre les règles PAM et SSH, les services, les fichiers, les montages
et les options de sécurité visibles depuis le conteneur.

Le test ne certifie pas la configuration de l'hôte, les clés privées des
utilisateurs, l'accès SSH avec une clé réelle ni les règles réseau externes.
Le test SSH a utilisé un fichier de clés publiques vide. La configuration
sshd a été validée et le port a répondu, mais une connexion utilisateur
complète n'a pas été vérifiée.

## 3. Contrôles mis en place

- **Mots de passe :** `pam_pwquality` impose 12 caractères minimum, avec une
  majuscule, une minuscule, un chiffre et un caractère spécial.
- **Historique et verrouillage :** PAM conserve les cinq derniers mots de
  passe et bloque après cinq échecs pendant 900 secondes.
- **SSH :** l'accès root et l'authentification par mot de passe sont
  désactivés. L'accès est limité à `shieldadmin` par clé publique.
- **Comptes :** le mot de passe root est verrouillé. La clé publique est
  montée depuis l'hôte en lecture seule et installée avec des permissions
  restreintes.
- **Système :** le script de démarrage protège des fichiers sensibles,
  applique les réglages sysctl autorisés, écrit la bannière et produit un
  inventaire SUID/SGID.
- **Services :** Nginx sert `/health`; SSH démarre et répond sur le port 22.
  Les workers Nginx tournent sous `appuser`.
- **Conteneur :** Compose retire les capabilities par défaut, n'ajoute que
  cinq capabilities nécessaires, active `no-new-privileges`, conserve
  Seccomp et limite mémoire, CPU et processus.
- **Montages :** les répertoires temporaires utilisent `noexec`, `nosuid` et
  `nodev`. Les clés publiques de l'hôte sont montées en lecture seule.

Le paquet Google Authenticator est présent, mais PAM ne l'exige pas pour SSH.
Le TOTP n'est donc pas un contrôle actif.

## 4. Résultats des tests

Le 27 novembre 2026, l'image a été construite et lancée avec Ubuntu 20.04 et
les restrictions Compose. Le conteneur est devenu `healthy`. Les contrôles
de syntaxe des scripts, `pycodestyle`, la configuration Compose et le point
de contrôle HTTP ont réussi.

Résultats de l'audit automatisé :

- Durcissement du noyau : `45%` (`10/22`)
- Sécurité du système de fichiers : `100%` (`7/7`)
- Sécurité des identités : `100%` (`14/14`)
- Sécurité des services : `80%` (`4/5`)
- Sécurité du conteneur : `86%` (`6/7`)
- Résultat global : `75%` (`41/55`), `FAIL`

Le rapport détaillé se trouve dans [audit_result.md](audit_result.md). Les
valeurs noyau refusées par le conteneur reflètent l'environnement de test et
doivent être contrôlées sur l'hôte de déploiement.

## 5. Risques résiduels

- Plusieurs paramètres sysctl ne sont pas appliqués dans le conteneur. Ils
  doivent être évalués et définis sur l'hôte ou dans la configuration Docker.
- Fail2ban est installé, mais le script de démarrage ne lance pas le service.
- Le système de fichiers racine reste monté en lecture-écriture.
- Le module TOTP est installé, mais l'authentification à deux facteurs
  n'est pas configurée pour SSH.
- L'accès avec une vraie clé publique n'a pas été testé de bout en bout.
- Les risques de l'hôte, du réseau, des clés privées et des mises à jour
  sortent du périmètre de cet audit de conteneur.

## 6. Validation

**Décision actuelle : NON APPROUVÉ POUR LA PRODUCTION**  
**Motif :** l'audit automatisé retourne `FAIL` et les risques résiduels
ci-dessus ne sont pas résolus.

La mise en production doit attendre la correction des points applicables,
puis un nouvel audit et un test d'accès SSH avec une vraie clé.

**Responsable de validation :** à compléter  
**Date de validation :** à compléter  
**Signature :** en attente de la revue QA
