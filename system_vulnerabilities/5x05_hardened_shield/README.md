# The Hardened Shield

## Présentation

Ce projet construit une image Ubuntu 20.04 avec Nginx pour le Web et OpenSSH
pour l'administration distante. Des scripts appliquent les réglages système,
PAM et SSH. Un audit Python vérifie les protections et produit un rapport
Markdown.

La clé publique est fournie au lancement. Aucune clé privée ni aucun mot de
passe ne sont intégrés à l'image.

## Démarrage rapide

Depuis la racine du dépôt :

```sh
cd system_vulnerabilities/5x05_hardened_shield
export AUTHORIZED_KEYS_FILE="$HOME/.ssh/authorized_keys"
docker compose up --build -d
docker compose ps
```

Le fichier de clés doit exister et contenir au moins une clé publique. Compose
publie les ports 80 et 22 de l'hôte. Ils doivent être libres. Nginx répond sur
`http://localhost/health`. Pour ouvrir une session :

```sh
ssh shieldadmin@localhost
```

Arrêter le conteneur :

```sh
docker compose down
```

## Construction et protections au lancement

Pour construire uniquement l'image :

```sh
docker build -t hardened-shield:latest .
```

Compose démarre les services en lecture seule avec des limites de 512 Mio de
mémoire, 1 CPU et 128 processus. Il retire les capacités par défaut et ajoute
uniquement celles utilisées par les services. Il active `no-new-privileges`,
conserve le profil Seccomp par défaut, protège les dossiers temporaires et
monte les journaux et le rapport dans des volumes persistants.

## Contrôles intégrés

- Nginx sert `/health` et ses workers fonctionnent sous `appuser`.
- SSH n'accepte que les clés publiques pour `shieldadmin`. L'accès root et
  l'authentification par mot de passe sont désactivés.
- PAM impose une longueur minimale de 12 caractères, les types de caractères
  requis, l'historique de cinq mots de passe et le verrouillage après cinq
  échecs.
- Fail2ban démarre avec le jail SSH et lit `/var/log/auth.log` via le groupe
  `adm`.
- Le mot de passe root est verrouillé. Le script protège les fichiers
  sensibles, applique les réglages sysctl disponibles et inventorie les
  fichiers SUID/SGID.
- La clé publique est montée en lecture seule depuis l'hôte et installée avec
  des permissions restreintes.

Le paquet Google Authenticator est installé, mais TOTP n'est pas activé dans
SSH. Les comptes doivent recevoir un secret TOTP avant de rendre ce facteur
obligatoire. Les paramètres de noyau globaux doivent être vérifiés sur l'hôte.

## Vérification de l'intégration

La validation a été exécutée sur Docker Desktop avec une image Ubuntu 20.04.
Pour éviter de remplacer des services déjà présents sur l'hôte, le test a
utilisé les ports hôte `18082` et `12224`, reliés aux ports conteneur 80 et 22.
Le conteneur est devenu `healthy`, `/health` a répondu `ok`, et une connexion
SSH avec une vraie clé publique a réussi. Le jail Fail2ban `sshd` surveillait
`/var/log/auth.log`.

L'audit automatisé a donné **100% (50/50), PASS** pour les contrôles applicables
au conteneur. Les paramètres du noyau contrôlés par l'hôte sont affichés en
`INFO`, hors score, et restent à vérifier sur la machine de déploiement. Ce
score ne signifie pas que TOTP est actif.

## Audit

Lancer l'audit dans le conteneur :

```sh
docker compose exec hardened-shield \
  python3 /opt/hardened-shield/scripts/audit.py
```

Le rapport est écrit dans le volume monté sur
`/var/lib/hardened-shield/audit_result.md`. Pour le copier dans le dépôt :

```sh
docker cp hardened-shield:/var/lib/hardened-shield/audit_result.md \
  ./audit_result.md
```

Le rapport versionné correspond aux derniers tests d'intégration. Il détaille
les résultats `PASS`, `FAIL` et `INFO` par catégorie.

## Fichiers du projet

```text
5x05_hardened_shield/
├── Dockerfile
├── docker-compose.yml
├── README.md
├── SECURITY.md
├── COMPLIANCE_REPORT.md
├── audit_result.md
├── config/
│   ├── fail2ban-default
│   ├── fail2ban-jail.local
│   ├── nginx.conf
│   └── sshd_config
└── scripts/
    ├── init-hardening.sh
    ├── init-identity.sh
    ├── init-services.sh
    └── audit.py
```

`SECURITY.md` décrit l'architecture et les procédures. `COMPLIANCE_REPORT.md`
présente le périmètre, les résultats et les risques résiduels.
