# The Hardened Shield

Image Docker de base pour les exercices du capstone: serveur Web Nginx,
administration SSH par clé, modules PAM, Fail2ban et scripts d'initialisation.

## Tâche 0: Dockerfile

Le Dockerfile part d'Ubuntu 20.04 minimal, installe uniquement les composants
nécessaires au service Web, SSH et aux politiques PAM. Nginx exécute ses workers
sous le compte non privilégié `appuser`; l'administration distante utilise le
compte distinct `shieldadmin`, sans mot de passe utilisable ni connexion root.
L'image ne contient aucune clé privée ou aucun secret applicatif. Les labels OCI
et le contrôle de santé HTTP sont inclus.

Les scripts d'initialisation sont copiés avec des permissions protégées et
exécutés au démarrage. Les scripts système ne peuvent pas imposer les paramètres
de noyau ni les options de montage au moteur Docker: ces protections doivent
aussi être configurées sur l'hôte ou dans `docker run` / Compose.

## Construire et lancer

```sh
docker build -t hardened-shield:latest system_vulnerabilities/5x05_hardened_shield
docker run --rm -p 8080:80 -p 2222:22 \\
  --mount type=bind,src=/secure/authorized_keys,dst=/run/secrets/authorized_keys,readonly \\
  hardened-shield:latest
```

Contrôler le serveur Web sur `http://localhost:8080/health`. Le fichier monté
`/secure/authorized_keys` doit contenir la clé publique autorisée. Sans cette
clé, le conteneur démarre mais SSH n'accepte aucune connexion. En production,
utiliser un secret Docker ou un orchestrateur de secrets.

## Tâche 1: durcissement système

`scripts/init-hardening.sh` est idempotent et retourne un code non nul si un
outil requis manque, si les permissions d'exécution sont insuffisantes ou si
une écriture essentielle échoue. Il configure les paramètres sysctl réseau et
noyau accessibles, règle `/tmp` et `/var/tmp` à `1777`, protège les fichiers
d'authentification, arrête les services facultatifs connus, consigne les fichiers
SUID/SGID détectés dans `/run/hardened-shield-suid-audit.txt`, puis installe la
bannière d'accès dans `/etc/issue` et `/etc/issue.net`. Les refus sysctl liés
aux capacités du conteneur et les montages temporaires sans `noexec` sont
signalés comme avertissements afin que l'opérateur applique le contrôle à
l'hôte ou au lancement Docker.

Pour appliquer les protections de montage au démarrage, ajouter par exemple:

```sh
--tmpfs /tmp:rw,noexec,nosuid,nodev,size=64m \\
--tmpfs /var/tmp:rw,noexec,nosuid,nodev,size=64m \\
--tmpfs /dev/shm:rw,noexec,nosuid,nodev,size=64m
```

Les paramètres de noyau non modifiables depuis un conteneur doivent être
explicitement passés au moteur Docker avec `--sysctl` ou définis sur l'hôte.
L'audit SUID/SGID est volontairement consultatif: les fichiers système légitimes
ne sont pas dépouillés automatiquement de leurs bits.

## Fichiers du projet

- `Dockerfile`: image Ubuntu 20.04, paquets réduits, comptes séparés,
  services, labels et HEALTHCHECK.
- `config/nginx.conf`: serveur HTTP avec workers non-root et endpoint `/health`.
- `config/sshd_config`: administration SSH par clé, sans root ni mot de passe.
- `scripts/init-hardening.sh`: applique les réglages noyau permis et rappelle
  les contrôles qui relèvent de l'hôte.
- `scripts/init-identity.sh`: valide une configuration SSH sans connexion root
  ou authentification par mot de passe.
- `scripts/init-services.sh`: initialise puis démarre les services.
- `scripts/audit.py`: contrôle les exigences statiques du Dockerfile.

Ce README sera complété à chaque tâche du projet avec les nouveaux contrôles,
les commandes d'utilisation et les résultats observés.
