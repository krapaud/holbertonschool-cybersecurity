# Rapport de conformité technique

**Projet :** The Hardened Shield
**Date :** 27 novembre 2026
**Périmètre :** critères du projet 5x05 et contrôles exécutés dans le conteneur

## 1. Résumé exécutif

L'image Ubuntu 20.04 a été construite puis démarrée avec Compose et les
restrictions prévues. Nginx, SSH et Fail2ban sont actifs. L'endpoint Web est
accessible, une connexion SSH par clé a réussi et l'audit a rendu
**100% (50/50), PASS** pour les contrôles applicables au conteneur.

Ce score ne certifie ni la configuration de l'hôte ni l'activation du TOTP.
Google Authenticator est installé, mais SSH ne demande pas encore le code
TOTP. Cette limite doit être prise en compte avant de déclarer la solution
conforme à une politique exigeant deux facteurs.

## 2. Périmètre

Les tests ont porté sur le Dockerfile, les scripts, les fichiers de
configuration et le lancement Compose sous Ubuntu 20.04. Pour ne pas
interrompre d'autres services de l'hôte, le test a relié les ports hôte
`18082` et `12224` aux ports conteneur 80 et 22.

La validation couvre la construction, le démarrage et l'état de santé du
conteneur, la réponse HTTP, l'authentification SSH par clé, la configuration
PAM et SSH, le démarrage du jail Fail2ban, les permissions, les montages et
les restrictions Docker. Les paramètres noyau globaux sont gérés par l'hôte
et doivent faire l'objet d'une vérification distincte.

## 3. Contrôles mis en place

- **Mots de passe :** longueur minimale de 12 caractères et exigences de
  classes de caractères via `pam_pwquality`.
- **Historique et verrouillage :** cinq mots de passe mémorisés par PAM;
  verrouillage après cinq échecs sur une fenêtre de 900 secondes.
- **SSH :** connexion root et authentification par mot de passe désactivées;
  clés publiques autorisées pour `shieldadmin`.
- **Comptes :** mot de passe root verrouillé et répertoires SSH protégés.
- **Système :** protection des fichiers sensibles, bannière et inventaire
  SUID/SGID.
- **Services :** Nginx, OpenSSH et Fail2ban démarrent sans intervention
  manuelle. Le jail `sshd` surveille `/var/log/auth.log`.
- **Conteneur :** système de fichiers racine en lecture seule, capacités
  limitées, `no-new-privileges`, profil Seccomp et limites de ressources.
- **Secrets :** clé publique fournie en montage lecture seule; aucun mot de
  passe ou secret n'est codé en dur dans l'image.

Le paquet Google Authenticator est installé, mais l'authentification TOTP
n'est pas activée pour SSH. Les secrets de chaque utilisateur doivent être
provisionnés avant de rendre ce second facteur obligatoire.

## 4. Résultats des tests

| Vérification | Résultat |
| --- | --- |
| Construction de l'image Ubuntu 20.04 | PASS |
| Démarrage Compose et état de santé | PASS |
| Réponse HTTP sur le port conteneur 80 | PASS, `/health` renvoie `ok` |
| Connexion SSH par clé sur le port conteneur 22 | PASS |
| Jail Fail2ban et lecture du journal SSH | PASS |
| Audit des contrôles applicables au conteneur | PASS, 100% (50/50) |

L'audit détaille les résultats `PASS`, `FAIL` et `INFO` dans
[`audit_result.md`](audit_result.md). Les réglages noyau gérés par l'hôte
apparaissent en `INFO` et ne sont pas inclus dans le score du conteneur.

## 5. Risques résiduels

- Les paramètres du noyau doivent être évalués et vérifiés sur chaque hôte
  Docker de production.
- TOTP n'est pas encore un facteur SSH obligatoire. Préparer les secrets
  utilisateurs, tester la récupération et activer le module PAM dans un
  déploiement contrôlé avant d'exiger le second facteur.
- Les tests ne certifient pas les règles réseau, les sauvegardes de l'hôte,
  la rotation des clés ni le processus de mise à jour des images.
- Les ports hôte 80 et 22 doivent être disponibles dans l'environnement cible.

## 6. Validation

**Résultat des critères d'intégration : PASS.** L'image se construit, Compose
démarre le service, les accès HTTP et SSH par clé fonctionnent et l'audit
réussit sur tous les contrôles qu'il mesure.

**Revue QA manuelle : en attente.** Le TOTP et les paramètres de sécurité de
l'hôte doivent être évalués selon la politique de déploiement avant toute
approbation de production.

**Responsable :** à compléter
**Date de signature :** à compléter
