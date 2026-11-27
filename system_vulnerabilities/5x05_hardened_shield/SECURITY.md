# Architecture et contrôles de sécurité

## 1. Vue d'ensemble de l'architecture

L'image part d'Ubuntu 20.04. Elle contient Nginx pour le serveur Web et
OpenSSH pour l'administration distante. Nginx sert une page de contrôle sur
`/health`. Son processus principal démarre avec les droits root pour ouvrir
les ports, puis ses workers utilisent le compte sans privilèges `appuser`.

Le compte `shieldadmin` est le seul autorisé à se connecter en SSH. Une clé
publique est fournie au lancement par le fichier indiqué dans
`AUTHORIZED_KEYS_FILE`. Le script d'entrée applique les réglages système et
d'identité, démarre SSH, puis garde Nginx au premier plan.

Le fichier `docker-compose.yml` publie les ports 80 et 22. Il impose des
limites mémoire, CPU et processus, retire les capabilities par défaut,
active `no-new-privileges` et monte les dossiers temporaires avec
`noexec`, `nosuid` et `nodev`.

## 2. Contrôles de sécurité

### Système et fichiers

- `init-hardening.sh` applique les réglages sysctl autorisés, protège les
  dossiers temporaires et certains fichiers système, désactive quelques
  services inutiles et produit un inventaire SUID/SGID.
- Le script écrit une bannière d'avertissement dans `/etc/issue` et
  `/etc/issue.net`.
- Les journaux Nginx appartiennent à root et au groupe `appuser`. Cela permet
  au processus principal d'ouvrir les journaux et aux workers d'y écrire.
- Docker peut refuser certains réglages noyau. Ces paramètres doivent alors
  être fournis par l'hôte ou par les options de lancement Docker.

### Comptes, PAM et SSH

- `pam_pwquality` impose une longueur minimale de 12 caractères et au moins
  une lettre majuscule, une minuscule, un chiffre et un caractère spécial.
- `pam_pwhistory` conserve les cinq derniers mots de passe.
- `pam_faillock` bloque un compte après cinq échecs, avec une période de
  verrouillage et une fenêtre de comptage de 900 secondes.
- SSH refuse les mots de passe et la connexion directe de root. Il accepte
  les clés publiques et limite l'accès à `shieldadmin`.
- Le mot de passe root est verrouillé.
- La clé fournie est montée en lecture seule, puis copiée dans
  `/home/shieldadmin/.ssh/authorized_keys` avec les permissions nécessaires.
- Le module PAM Google Authenticator est installé, mais le script ne l'ajoute
  pas à la configuration SSH. L'authentification TOTP n'est donc pas active.

### Conteneur et services

- Compose retire toutes les capabilities par défaut et n'ajoute que
  `NET_BIND_SERVICE`, `CHOWN`, `SETUID`, `SETGID` et `SYS_CHROOT`.
- `no-new-privileges` et le profil Seccomp par défaut de Docker limitent les
  changements de privilèges et les appels système disponibles.
- Les limites Compose sont de 512 Mio de mémoire, 1 CPU et 128 processus.
- `/tmp`, `/var/tmp` et `/dev/shm` sont des montages temporaires avec
  `noexec`, `nosuid` et `nodev`.
- Le contrôle de santé vérifie l'adresse locale `/health` toutes les
  30 secondes.

L'audit actuel indique que Fail2ban est installé, mais que le script de
démarrage ne lance pas son service. Il indique aussi que le système de
fichiers racine du conteneur est en lecture-écriture. Ces deux protections
ne doivent pas être considérées comme actives.

## 3. Utilisation

Depuis ce dossier, choisir un fichier contenant les clés publiques que
`shieldadmin` pourra utiliser, puis démarrer l'image avec Compose :

```sh
export AUTHORIZED_KEYS_FILE="$HOME/.ssh/authorized_keys"
docker compose up --build -d
docker compose ps
```

Le fichier choisi doit exister et contenir une clé publique valide. Pour
vérifier Nginx, ouvrir `http://localhost/health` ou lancer :

```sh
curl --fail http://localhost/health
```

La connexion SSH utilise la clé privée correspondante :

```sh
ssh shieldadmin@localhost
```

Les ports hôte 80 et 22 doivent être libres. Pour arrêter le service :

```sh
docker compose down
```

Ne place pas de mot de passe ou de clé privée dans le Dockerfile, dans
l'image ou dans le dépôt. `AUTHORIZED_KEYS_FILE` fournit seulement la clé
publique autorisée.

## 4. Procédure d'audit

L'audit doit être lancé dans le conteneur en fonctionnement :

```sh
docker compose exec hardened-shield \
  python3 /opt/hardened-shield/scripts/audit.py
```

Le programme vérifie le noyau, les permissions et montages, PAM et SSH, les
services, les capacités, Seccomp et les autres restrictions visibles dans le
conteneur. Il affiche un score par catégorie et un score global. Il conserve
les statuts `PASS` et `FAIL` et écrit `audit_result.md`.

Pour récupérer le rapport produit dans le conteneur :

```sh
docker cp hardened-shield:/opt/hardened-shield/audit_result.md \
  ./audit_result.md
```

Le rapport versionné avec ce projet correspond au dernier test effectué sur
l'image Ubuntu 20.04 avec les restrictions Compose : `75%` (`41/55`), statut
`FAIL`. Les contrôles PAM et du système de fichiers ont réussi. Le rapport
signale les paramètres noyau contrôlés par l'hôte, Fail2ban non démarré et le
système de fichiers racine en lecture-écriture.

Un réglage sysctl bloqué dans Docker ne signifie pas que l'hôte est protégé.
Vérifier le réglage sur l'hôte ou le fournir explicitement avec Docker.
Le bilan formel et les risques résiduels sont détaillés dans
[`COMPLIANCE_REPORT.md`](COMPLIANCE_REPORT.md).

## 5. Entretien

- Reconstruire l'image après les mises à jour de sécurité et vérifier les
  versions des paquets installés.
- Relancer l'audit après chaque changement de l'image, de Compose ou des
  fichiers dans `config/`.
- Examiner les résultats `FAIL` et corriger les contrôles manquants avant
  d'utiliser l'image en production.
- Garder `AUTHORIZED_KEYS_FILE` à jour et retirer les clés qui ne sont plus
  nécessaires.
- Examiner les journaux Nginx et les événements SSH; le volume Compose
  `nginx-logs` conserve les journaux Nginx après le remplacement du conteneur.
- Réviser régulièrement les règles PAM, les directives SSH, les limites
  Compose et les paramètres sysctl de l'hôte.
- Tester les modifications dans un environnement de développement avant de
  les déployer.
