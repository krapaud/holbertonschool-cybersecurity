# Architecture et contrôles de sécurité

## 1. Vue d'ensemble

L'image utilise Ubuntu 20.04, Nginx pour le Web et OpenSSH pour
l'administration. Le script d'entrée prépare les services et conserve Nginx
au premier plan. L'image ne contient pas de clé privée ni de mot de passe.

Le compte `shieldadmin` est le seul autorisé en SSH. Compose monte un fichier
de clés publiques depuis l'hôte et le script l'installe dans
`authorized_keys`. Nginx sert le contrôle de santé `/health`.

## 2. Contrôles de sécurité

### Système et fichiers

- `init-hardening.sh` applique les réglages sysctl permis, protège les
  répertoires temporaires et les fichiers sensibles, désactive certains
  services inutiles et crée un inventaire SUID/SGID.
- Une bannière est écrite dans `/etc/issue` et `/etc/issue.net`.
- Le système de fichiers racine est monté en lecture seule par Compose.
  Les répertoires nécessaires à l'exécution sont fournis par des montages
  temporaires ou des volumes.
- Les paramètres de noyau globaux qui ne sont pas modifiables depuis le
  conteneur sont signalés par l'audit et doivent être vérifiés sur l'hôte.

### Comptes, PAM et SSH

- `pam_pwquality` exige une longueur minimale de 12 caractères, une majuscule,
  une minuscule, un chiffre et un caractère spécial.
- `pam_pwhistory` conserve les cinq derniers mots de passe.
- `pam_faillock` bloque après cinq échecs dans une fenêtre de 900 secondes.
- SSH refuse les connexions root et les mots de passe. Il accepte les clés
  publiques et limite l'accès à `shieldadmin`.
- Le mot de passe root est verrouillé. La clé publique hôte est montée en
  lecture seule et installée avec des permissions restreintes.
- Google Authenticator est installé, mais le facteur TOTP n'est pas activé
  dans SSH. Il faut provisionner les secrets utilisateurs avant de l'exiger.

### Services et conteneur

- Nginx, SSH et Fail2ban sont lancés au démarrage et vérifiés par le script
  d'entrée. Le jail `sshd` lit `/var/log/auth.log`.
- Fail2ban s'exécute avec l'identité `root:adm` pour lire les journaux sans
  droits supplémentaires de lecture discrétionnaire.
- Compose retire les capacités par défaut et n'ajoute que les capacités
  requises par les services. Il active `no-new-privileges` et garde le profil
  Seccomp par défaut.
- Compose limite la mémoire à 512 Mio, le CPU à 1 et les processus à 128.
- Les montages temporaires utilisent `noexec`, `nosuid` et `nodev`. Les
  journaux et le rapport d'audit sont conservés dans des volumes.
- Le HEALTHCHECK vérifie `/health` toutes les 30 secondes.

## 3. Utilisation

Depuis ce dossier, sélectionner un fichier contenant les clés publiques
autorisées, puis démarrer le conteneur :

```sh
export AUTHORIZED_KEYS_FILE="$HOME/.ssh/authorized_keys"
docker compose up --build -d
docker compose ps
```

Le fichier doit exister et contenir une clé publique valide. Les ports hôte
80 et 22 doivent être libres. Vérifier le serveur Web avec :

```sh
curl --fail http://localhost/health
```

Se connecter avec la clé privée correspondante :

```sh
ssh shieldadmin@localhost
```

Pour arrêter le conteneur :

```sh
docker compose down
```

Ne pas placer de mot de passe, de clé privée ou de secret TOTP dans l'image ou
le dépôt. `AUTHORIZED_KEYS_FILE` fournit une clé publique, pas une clé privée.

## 4. Procédure d'audit

Lancer l'audit dans le conteneur en fonctionnement :

```sh
docker compose exec hardened-shield \
  python3 /opt/hardened-shield/scripts/audit.py
```

L'outil vérifie les réglages du noyau visibles, les permissions et montages,
PAM et SSH, les services et les restrictions Docker. Il écrit le rapport dans
`/var/lib/hardened-shield/audit_result.md`, un volume persistant. Pour le
copier dans le dépôt :

```sh
docker cp hardened-shield:/var/lib/hardened-shield/audit_result.md \
  ./audit_result.md
```

Lors du test d'intégration du 27 novembre 2026, l'image Ubuntu 20.04 est
devenue `healthy`, `/health` a répondu `ok`, SSH par clé a réussi et Fail2ban
a surveillé `/var/log/auth.log`. L'audit a indiqué `100% (50/50), PASS` pour
les contrôles applicables au conteneur. Les réglages de noyau gérés par l'hôte
apparaissent en `INFO` hors score. Le rapport est conservé dans
[`audit_result.md`](audit_result.md).

Ce résultat couvre uniquement les contrôles implémentés dans l'audit. Il ne
certifie pas les paramètres de l'hôte ni l'activation du TOTP. Le détail des
risques et tests figure dans [`COMPLIANCE_REPORT.md`](COMPLIANCE_REPORT.md).

## 5. Entretien

- Reconstruire l'image après les mises à jour de sécurité et vérifier les
  versions des paquets.
- Relancer l'audit après toute modification de l'image, de Compose ou des
  fichiers de configuration.
- Examiner les résultats `FAIL` et `INFO`, puis vérifier les paramètres de
  l'hôte avant le déploiement.
- Mettre à jour les clés publiques et retirer celles qui ne sont plus
  nécessaires.
- Examiner régulièrement les journaux Nginx, SSH et Fail2ban.
- Provisionner et tester les secrets TOTP avant d'activer cette exigence.
