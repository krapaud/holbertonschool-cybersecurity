# The Hardened Shield

## Présentation

Ce projet construit une image Ubuntu 20.04 avec Nginx pour le Web et
OpenSSH pour l'administration. Des scripts appliquent des règles système,
PAM et SSH au démarrage. Un outil Python vérifie ensuite les contrôles actifs
et écrit un rapport d'audit.

La clé publique SSH est fournie au lancement. L'image ne contient pas de clé
privée ni de mot de passe codé en dur.

## Démarrage rapide

Depuis la racine du dépôt, aller dans le dossier du projet :

```sh
cd system_vulnerabilities/5x05_hardened_shield
```

Vérifier que le fichier choisi contient les clés publiques autorisées, puis
indiquer son chemin et démarrer avec Compose :

```sh
export AUTHORIZED_KEYS_FILE="$HOME/.ssh/authorized_keys"
docker compose up --build -d
docker compose ps
```

Le fichier doit exister et contenir au moins une clé publique. Le démarrage
publie les ports hôte 80 et 22, qui doivent être libres. Nginx répond sur
`http://localhost/health`. Pour se connecter avec la clé privée correspondante :

```sh
ssh shieldadmin@localhost
```

Pour arrêter le conteneur :

```sh
docker compose down
```

## Construction et lancement

Pour construire l'image seule depuis ce dossier :

```sh
docker build -t hardened-shield:latest .
```

Pour démarrer l'image avec les limites et les options de sécurité du projet,
utiliser Compose :

```sh
export AUTHORIZED_KEYS_FILE="$HOME/.ssh/authorized_keys"
docker compose up --build -d
```

Compose limite la mémoire à 512 Mio, le CPU à 1 et le nombre de processus à
128. Il publie les ports 80 et 22, retire les capabilities par défaut,
applique `no-new-privileges`, protège les montages temporaires et conserve
les journaux Nginx dans un volume.

## Contrôles de sécurité

- Nginx exécute ses workers sous le compte `appuser`.
- SSH n'accepte pas les mots de passe ni la connexion directe de root.
  Seul `shieldadmin` est autorisé, avec une clé publique.
- PAM impose 12 caractères minimum, les quatre types de caractères,
  l'historique des cinq derniers mots de passe et le verrouillage après cinq
  échecs.
- Le mot de passe root est verrouillé. Des fichiers sensibles et les
  répertoires temporaires sont protégés.
- Les scripts appliquent les réglages sysctl autorisés, valident Nginx et
  SSH, démarrent les services et contrôlent `/health`.
- L'audit vérifie le noyau, les fichiers, les identités, les services et les
  protections du conteneur.

Certains contrôles restent incomplets. Les réglages sysctl refusés dans un
conteneur doivent être définis ou vérifiés sur l'hôte. Fail2ban est installé,
mais son service n'est pas démarré. Le système de fichiers racine est en
lecture-écriture. Google Authenticator est installé, mais TOTP n'est pas
activé dans la configuration SSH.

## Audit

Lancer l'audit dans le conteneur :

```sh
docker compose exec hardened-shield \
  python3 /opt/hardened-shield/scripts/audit.py
```

Le programme affiche les résultats avec les statuts `PASS` et `FAIL`. Il
génère `audit_result.md` à la racine du projet et dans `scripts/`. Pour
récupérer le rapport créé dans le conteneur :

```sh
docker cp hardened-shield:/opt/hardened-shield/audit_result.md \
  ./audit_result.md
```

Le dernier audit versionné a obtenu `75%` (`41/55`), statut `FAIL`. Les
contrôles du système de fichiers et des identités ont réussi. Les échecs
restants sont détaillés dans [`audit_result.md`](audit_result.md).

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
│   ├── nginx.conf
│   └── sshd_config
└── scripts/
    ├── init-hardening.sh
    ├── init-identity.sh
    ├── init-services.sh
    ├── audit.py
    └── audit_result.md
```

`SECURITY.md` décrit l'architecture et les contrôles. `COMPLIANCE_REPORT.md`
présente le périmètre, les tests, les risques résiduels et la décision de
validation. Le rapport indique `FAIL`; l'image n'est pas approuvée pour la
production tant que les risques restants ne sont pas traités.
