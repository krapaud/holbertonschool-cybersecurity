# The Hardened Shield

Ce dossier contient l'image et les fichiers du projet The Hardened Shield.
Elle utilise Nginx pour le Web et SSH pour l'administration.

## Tâche 0: Dockerfile

Le Dockerfile utilise Ubuntu 20.04 et installe Nginx, SSH et les modules PAM.
Les processus Nginx tournent avec le compte `appuser`. Le compte `shieldadmin`
sert à l'accès SSH. La connexion root et les mots de passe SSH sont désactivés.
Il faut fournir une clé publique au démarrage. Aucun secret n'est écrit dans
l'image. Le Dockerfile contient aussi des labels et un HEALTHCHECK.

Les scripts sont copiés dans l'image et lancés au démarrage. Les réglages du
noyau et les options de montage qui sont bloqués dans un conteneur se règlent
avec Docker ou sur l'hôte.

## Construire et lancer

```sh
docker build -t hardened-shield:latest system_vulnerabilities/5x05_hardened_shield
docker run --rm -p 8080:80 -p 2222:22 \\
  --mount type=bind,src=/secure/authorized_keys,dst=/run/secrets/authorized_keys,readonly \\
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
en root, `2` si l'inventaire SUID/SGID échoue, et `3` si la bannière ne peut pas
être écrite. Si Docker refuse
un paramètre sysctl, un avertissement indique qu'il faut le régler avec Docker
ou sur l'hôte. Le script ne change pas les montages.

Pour appliquer les protections de montage au démarrage, ajouter par exemple:

```sh
--tmpfs /tmp:rw,noexec,nosuid,nodev,size=64m \\
--tmpfs /var/tmp:rw,noexec,nosuid,nodev,size=64m \\
--tmpfs /dev/shm:rw,noexec,nosuid,nodev,size=64m
```

Les paramètres noyau refusés par Docker se règlent avec `--sysctl` ou sur
l'hôte. La liste SUID/SGID se trouve dans
`/run/hardened-shield-suid-audit.txt`. Je ne supprime pas ces permissions
automatiquement, car certains programmes en ont besoin.

## Fichiers du projet

- `Dockerfile`: construit l'image et copie les scripts.
- `config/nginx.conf`: configuration du serveur Web.
- `config/sshd_config`: configuration du serveur SSH.
- `scripts/init-hardening.sh`: applique les réglages système disponibles.
- `scripts/init-identity.sh`: installe la clé publique et vérifie SSH.
- `scripts/init-services.sh`: prépare le conteneur et démarre les services.
- `scripts/audit.py`: vérifie quelques exigences du Dockerfile.

Ce README sera complété à chaque tâche du projet avec les nouveaux contrôles,
les commandes d'utilisation et les résultats observés.
