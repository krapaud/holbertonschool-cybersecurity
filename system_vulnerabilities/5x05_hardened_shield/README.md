# The Hardened Shield

Ce dossier contient l'image et les fichiers du projet The Hardened Shield.
Elle utilise Nginx pour le Web et SSH pour l'administration.

## Tâche 0: Dockerfile

Le Dockerfile utilise Ubuntu 20.04 et installe Nginx, SSH et les modules PAM.
Les processus Nginx tournent avec le compte `appuser`. Le compte `shieldadmin`
sert à l'accès SSH. La connexion root et les mots de passe SSH sont
désactivés.
Il faut fournir une clé publique au démarrage. Aucun secret n'est écrit dans
l'image. Le Dockerfile contient aussi des labels et un HEALTHCHECK.

Les scripts sont copiés dans l'image et lancés au démarrage. Les réglages du
noyau et les options de montage qui sont bloqués dans un conteneur se règlent
avec Docker ou sur l'hôte.

## Construire et lancer

```sh
docker build -t hardened-shield:latest \
  system_vulnerabilities/5x05_hardened_shield
docker run --rm -p 8080:80 -p 2222:22 \
  -v /secure/authorized_keys:/run/secrets/authorized_keys:ro \
  hardened-shield:latest
```

Ouvrir `http://localhost:8080/health` pour vérifier Nginx. Le fichier
`/secure/authorized_keys` doit contenir la clé publique. Sans ce fichier, le
conteneur démarre mais il n'est pas possible de se connecter en SSH. Pour un
vrai déploiement, fournir la clé avec Docker Secrets ou un outil équivalent.

## Tâche 1: script de durcissement système

Au démarrage, `scripts/init-hardening.sh` applique les réglages sysctl permis,
protège les dossiers temporaires et certains fichiers, arrête des services
inutiles, liste les fichiers SUID/SGID et écrit une bannière légale. Relancer
le script ne duplique pas sa configuration.

Le script retourne `0` quand les étapes se terminent, `1` s'il n'est pas lancé
en root, `2` si l'inventaire SUID/SGID échoue, et `3` si l'écriture de la
bannière échoue. Si Docker refuse un paramètre sysctl, un avertissement
indique qu'il faut le régler avec Docker
ou sur l'hôte. Le script ne change pas les montages.

Pour appliquer les protections de montage au démarrage, ajouter par exemple:

```sh
--tmpfs /tmp:rw,noexec,nosuid,nodev,size=64m \
--tmpfs /var/tmp:rw,noexec,nosuid,nodev,size=64m \
--tmpfs /dev/shm:rw,noexec,nosuid,nodev,size=64m
```

Les paramètres noyau refusés par Docker se règlent avec `--sysctl` ou sur
l'hôte. La liste SUID/SGID se trouve dans
`/run/hardened-shield-suid-audit.txt`. Je ne supprime pas ces permissions
automatiquement, car certains programmes en ont besoin.

## Tâche 2: script de durcissement de l'identité

`scripts/init-identity.sh` configure les règles PAM de mot de passe (12
caractères minimum, catégories de caractères, historique des cinq derniers
mots de passe), le verrouillage après cinq échecs et les directives SSH.
L'accès SSH est limité à `shieldadmin`, les mots de passe SSH et la connexion
root sont désactivés, et le mot de passe du compte root est verrouillé.
La clé publique montée dans `/run/secrets/authorized_keys` est installée avec
des permissions privées au démarrage.

Les fichiers PAM, SSH et les réglages pwquality/faillock déjà présents sont
sauvegardés avec le suffixe `.backup` avant leur première modification. Le
script peut être relancé: il remplace les règles qu'il gère et conserve les
autres réglages. Les paramètres appliqués se trouvent dans
`/etc/security/pwquality.conf` et `/etc/security/faillock.conf`.

Le script retourne `0` si les réglages sont installés et vérifiés, `1` s'il
n'est pas lancé en root ou si une commande manque, `2` si un fichier ou le
module PAM faillock est absent, `3` si une sauvegarde ou une modification
échoue, et `4` si la vérification finale échoue.

## Tâche 3: démarrage et contrôle des services

`scripts/init-services.sh` relance les scripts de durcissement de façon
ordonnée, valide les configurations Nginx et SSH, démarre SSH, puis vérifie
qu'il répond avec sa bannière sur le port 22. Nginx est lancé au premier plan
pour que Docker suive son processus. Le script interroge `/health` jusqu'à dix
secondes avant de déclarer le démarrage réussi. Si Nginx répond déjà à ce
contrôle, le script ne lance pas un deuxième serveur.

Les codes de sortie sont `0` si les contrôles réussissent ou si les services
sont déjà disponibles, `1` si root ou une commande requise manque, `2` si une
configuration de service est invalide, `3` si SSH ne démarre pas ou ne répond
pas, et `4` si le contrôle Web échoue ou si Nginx s'arrête.

## Tâche 4: audit de sécurité

`scripts/audit.py` contrôle le noyau, les permissions et montages, PAM et SSH,
les processus attendus et les restrictions visibles du conteneur. Il affiche
les résultats de chaque contrôle, un score par catégorie et un score global.
Le statut est `PASS` uniquement si tous les contrôles réussissent. Le script
écrit aussi le rapport Markdown dans `audit_result.md`.

Pour le noyau, il vérifie notamment le routage, les redirections et le filtrage
IPv4/IPv6, les SYN cookies, les paquets martiens, la randomisation mémoire et
les restrictions d'accès aux informations du noyau.
Les valeurs sont lues avec `sysctl -n`, puis dans `/proc/sys` si la commande
n'est pas disponible. Les contrôles conteneur vérifient aussi le filtre
Seccomp.

Lancer l'audit dans le conteneur pour mesurer ses réglages actifs:

```sh
python3 /opt/hardened-shield/scripts/audit.py
```

Un autre chemin de sortie peut être fourni avec `--output chemin.md`. Le code
de sortie est `0` si tous les contrôles passent, `1` si au moins un contrôle
échoue, et `2` si le rapport ne peut pas être écrit. Les options de lancement
Les options Docker, comme les capabilities et les montages en lecture seule,
sont vérifiées sur l'environnement d'exécution.

## Fichiers du projet

- `Dockerfile`: construit l'image et copie les scripts.
- `config/nginx.conf`: configuration du serveur Web.
- `config/sshd_config`: configuration du serveur SSH.
- `scripts/init-hardening.sh`: applique les réglages système disponibles.
- `scripts/init-identity.sh`: configure PAM, faillock, SSH et verrouille root.
- `scripts/init-services.sh`: applique les préparations, démarre SSH et Nginx,
  puis contrôle leurs réponses.
- `scripts/audit.py`: vérifie les contrôles actifs et produit
  `audit_result.md`.
- `audit_result.md`: emplacement du rapport Markdown généré par l'audit.

Ce README sera complété à chaque tâche avec les contrôles, les commandes
d'utilisation et les résultats observés.
