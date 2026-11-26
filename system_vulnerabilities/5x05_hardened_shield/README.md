# The Hardened Shield

Image Docker de base pour les exercices du capstone: serveur Web Nginx,
administration SSH par clé, modules PAM, Fail2ban et scripts d'initialisation.

## Première étape: Dockerfile

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

## Contenu

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
