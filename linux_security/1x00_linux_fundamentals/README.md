# Linux Fundamentals : Mini-cours

> **Dépôt :** holbertonschool-cybersecurity  
> **Répertoire :** `linux_security/1x00_linux_fundamentals`

---

## Who Dis ? : Transfert de fichiers et vérification d'identité

### Commandes clés : `whoami`, `scp`, `ssh`, `chmod`

Lorsqu'on intervient sur un serveur de production, la règle d'or est simple : **on ne bricole pas directement sur la cible**. On prépare un script en local, on le teste, puis on le déploie de façon propre et contrôlée.

#### `whoami` : Qui suis-je ?

```bash
whoami

```text

Cette commande affiche le **nom d'utilisateur effectif** du processus courant. C'est le premier réflexe à avoir après une connexion ou une élévation de privilèges : confirmer son contexte d'exécution.

#### `chmod` : Rendre un script exécutable

```bash
chmod +x 0-its_me.sh

```text

Sous Linux, un fichier texte n'est pas exécutable par défaut. `chmod +x` ajoute le bit d'exécution pour que le shell puisse le lancer directement avec `./`.

#### `scp` : Copie sécurisée

```bash
# Envoyer un fichier vers la machine distante
scp 0-its_me.sh student@<IP>:/home/student/

# Récupérer un fichier depuis la machine distante
scp student@<IP>:/home/student/0-flag.txt .

```text

`scp` (Secure Copy Protocol) utilise le protocole SSH pour transférer des fichiers de façon chiffrée. C'est la méthode standard pour déployer un payload connu sans toucher à la production.

#### `ssh` : Exécution distante

```bash
ssh student@<IP> "./0-its_me.sh"

```text

On peut passer une commande directement à `ssh` sans ouvrir un shell interactif. C'est utile pour exécuter ponctuellement un script et récupérer sa sortie.

**Fichiers :** `0-its_me.sh`, `0-flag.txt`

---

## The Needle in the Haystack : Recherche avancée avec `find`

### Commandes clés : `find`, redirection de `stderr`

#### `find` : Trouver des fichiers par critères multiples

`find` est l'outil de recherche de base sous Linux. Sa puissance vient de la combinaison de critères :

| Option | Signification |
| --- | --- |
| `-type f` | Fichier régulier uniquement |
| `-mtime -7` | Modifié il y a moins de 7 jours |
| `-size +1M` | Taille supérieure à 1 Mo |
| `! -name "*.gz"` | Exclut les archives `.gz` |

```bash
find "$1" -type f -mtime -7 -size +1M ! -name "*.gz" 2>/dev/null

```text

#### `2>/dev/null` : Ignorer les erreurs de permission

Lors d'une recherche récursive, `find` tente d'accéder à des répertoires auxquels l'utilisateur n'a peut-être pas accès, générant des `Permission denied`. La redirection `2>/dev/null` envoie la sortie d'erreur (`stderr`, descripteur 2) vers `/dev/null` (la poubelle), gardant la sortie propre.

**Fichiers :** `1-find_complex.sh`, `1-flag.txt`

---

## Content Mining : Grep récursif pour trouver des secrets

### Commandes clés : `grep`, `-r`, `-l`

#### `grep` : Chercher du contenu dans des fichiers

```bash
grep -rl "password = " "$1" 2>/dev/null

```text

| Option | Signification |
| --- | --- |
| `-r` | Récursif (parcourt les sous-répertoires) |
| `-l` | Affiche uniquement le nom du fichier (pas la ligne) |

On cherche ici la chaîne littérale `password =` dans tout `/etc`. C'est une technique classique de reconnaissance : des développeurs laissent parfois des mots de passe en clair dans des fichiers de configuration.

> **Bonne pratique Cybersec :** ne jamais stocker de credentials en clair dans des fichiers de config. Utiliser des variables d'environnement ou un gestionnaire de secrets (Vault, AWS Secrets Manager…).

**Fichiers :** `2-grep_secrets.sh`, `2-flag.txt`

---

## The Piping Logic : Chaîner les commandes avec les pipes

### Commandes clés : `ls`, `awk`, `sort`, `uniq`, `head`

#### Le pipe `|` : La philosophie Unix

Unix repose sur un principe : **chaque programme fait une seule chose, et la fait bien**. Le pipe `|` connecte la sortie d'une commande à l'entrée de la suivante, formant des pipelines puissants sans créer de fichiers temporaires.

```bash
ls -l "$1" | awk '{print $3}' | sort | uniq -c | sort -rn | head -1

```text

Décomposition :

| Étape | Commande | Rôle |
| --- | --- | --- |
| 1 | `ls -l $1` | Liste tous les fichiers avec leurs métadonnées |
| 2 | `awk '{print $3}'` | Extrait la 3e colonne : le propriétaire |
| 3 | `sort` | Trie les noms pour regrouper les doublons |
| 4 | `uniq -c` | Compte les occurrences consécutives |
| 5 | `sort -rn` | Trie par nombre décroissant |
| 6 | `head -1` | Garde uniquement la première ligne (le max) |

**Fichiers :** `3-stats.sh`, `3-flag.txt`

---

## The SUID Audit : Chasse aux vecteurs d'élévation de privilèges

### Commandes clés : `find -perm`

#### Le bit SUID : Pourquoi c'est dangereux

Le bit **SUID** (Set User ID) fait s'exécuter un programme avec les droits de son **propriétaire**, et non ceux de l'utilisateur qui le lance. C'est nécessaire pour des commandes comme `passwd` (qui doit pouvoir écrire `/etc/shadow` en tant que root).

Mais si un attaquant ou un administrateur inattentif place le bit SUID sur `bash` ou `vim`, **n'importe quel utilisateur peut devenir root**.

```bash
find "$1" -perm -4000 -type f 2>/dev/null

```text

| Option | Signification |
| --- | --- |
| `-perm -4000` | Le bit SUID (octal 4000) est positionné |
| `-type f` | Fichiers uniquement (pas les répertoires) |

> **Audit régulier :** lister les binaires SUID est l'une des premières vérifications d'un audit de sécurité Linux. Des outils comme `linpeas` font exactement cela automatiquement.

**Fichiers :** `4-suid_hunter.sh`, `4-flag.txt`

---

## The Immortal File : Attributs étendus avec `chattr`

### Commandes clés : `chattr`, `lsattr`

#### Le bit Immutable : Au-delà des permissions classiques

Les permissions Unix (`rwx`) ne sont pas le seul mécanisme de protection des fichiers. Linux dispose d'**attributs étendus** gérés par `chattr` :

```bash
# Voir les attributs d'un fichier
lsattr /home/larry/malware.sh

# Retirer le bit immutable
chattr -i /home/larry/malware.sh

# Supprimer le fichier
rm /home/larry/malware.sh

```text

| Attribut | Effet |
| --- | --- |
| `+i` (immutable) | Interdit toute modification, suppression, renommage : **même pour root** |
| `+a` (append only) | Seul l'ajout en fin de fichier est autorisé |

> **Cas concret :** les rootkits utilisent parfois `chattr +i` pour se protéger. Pour contrer cela, il faut les droits CAP_LINUX_IMMUTABLE ou être root, puis utiliser `chattr -i` avant de supprimer.

**Fichiers :** `5-unlock.sh`, `5-flag.txt`

---

## The Collaboration Folder : SGID et Sticky Bit

### Commandes clés : `mkdir`, `chown`, `chmod`, bits spéciaux

#### Les bits spéciaux : SGID et Sticky Bit

En plus du SUID, Linux dispose de deux autres bits spéciaux applicables aux **répertoires** :

##### SGID sur un répertoire

```bash
chmod g+s /shared/devs

```text

Tout fichier créé dans ce répertoire hérite automatiquement du **groupe du répertoire**, et non du groupe primaire de l'utilisateur créateur. Idéal pour un espace de travail collaboratif.

##### Sticky Bit

```bash
chmod +t /shared/devs

```text

Dans un répertoire avec le Sticky Bit, un utilisateur ne peut supprimer **que ses propres fichiers**, pas ceux des autres. C'est le comportement de `/tmp`.

##### Mise en place complète

```bash
mkdir -p "$1"
chown root:"$2" "$1"
chmod 2770 "$1"   # 2 = SGID, 7 = rwx owner, 7 = rwx group, 0 = no other
chmod +t "$1"     # Sticky Bit

```text

| Bit octal | Signification |
| --- | --- |
| `4000` | SUID |
| `2000` | SGID |
| `1000` | Sticky Bit |

**Fichiers :** `6-setup_shared.sh`, `6-flag.txt`

---

## The Audit Gateway : `sudo` pour déléguer sans ACL

### Commandes clés : `sudo`, `visudo`, wrapper script

#### Déléguer un accès précis avec `sudo`

L'objectif est de permettre à l'utilisateur `auditor` de lire un fichier sensible **sans** :

- modifier son propriétaire,

- utiliser les ACLs,

- l'ajouter à un groupe privilégié.

La solution : créer un **wrapper** (commande enveloppante) qui ne fait qu'une chose précise, puis autoriser son exécution via `sudo`.

```bash
# Créer le wrapper
cat << 'EOF' > /usr/local/bin/audit-read-secret
#!/bin/bash
cat /var/www/html/secret_config.php
EOF
chmod 750 /usr/local/bin/audit-read-secret

# Autoriser l'auditor à l'exécuter sans mot de passe
echo "auditor ALL=(root) NOPASSWD: /usr/local/bin/audit-read-secret" \
    >> /etc/sudoers.d/auditor

```text

> **Principe du moindre privilège :** le wrapper n'accepte aucun argument contrôlé par l'utilisateur. Cela empêche une exploitation du type `sudo cat /etc/shadow` en substituant le chemin.

**Fichiers :** `7-audit_gateway.sh`, `7-flag.txt`

---

## The Log Creation Policy : `logrotate` et SGID pour les logs

### Commandes clés : `logrotate`, `chmod g+s`, `chown`

#### Garantir la lisibilité des logs futurs sans ACL

Le service `www-data` doit pouvoir lire tous les logs dans `/var/log/app/`, y compris ceux créés ultérieurement par root. Sans ACL, on combine deux mécanismes :

1. **SGID sur le répertoire** : les nouveaux fichiers héritent du groupe `www-data`.

2. **Politique logrotate** : force les permissions `0640` et le propriétaire `root:www-data` sur les fichiers rotatés/créés.

```bash
# Configuration du répertoire
chown root:"$2" "$1"
chmod 2750 "$1"   # SGID + rwxr-x---

# Politique logrotate
cat << EOF > /etc/logrotate.d/app
$1/*.log {
    create 0640 root $2
    rotate 7
    daily
    missingok
    notifempty
}
EOF

```text

#### Récapitulatif `logrotate`

| Directive | Signification |
| --- | --- |
| `create 0640 root www-data` | Crée le nouveau fichier avec ces droits |
| `rotate 7` | Conserve 7 archives |
| `daily` | Rotation quotidienne |
| `missingok` | Pas d'erreur si le fichier est absent |

> **Pourquoi pas les ACLs ?** Les ACLs ne se propagent pas toujours aux fichiers nouvellement créés sans `default ACL`. Le SGID + logrotate est une approche plus portable et explicite.

**Fichiers :** `8-log_policy.sh`, `8-flag.txt`
