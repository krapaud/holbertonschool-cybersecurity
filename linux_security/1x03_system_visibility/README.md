# System Visibility : Mini-cours

> **Dépôt :** holbertonschool-cybersecurity
> **Répertoire :** `linux_security/1x03_system_visibility`

---

## Vue d'ensemble

La visibilité système, c'est la capacité à **voir ce qui se passe** sur une machine en temps réel ou en analyse post-incident. Avant de détecter une intrusion, il faut savoir lire ce que le système te dit : quels processus tournent, qui écoute sur quel port, qu'est-ce que les logs racontent.

Pense à ça comme être le gardien d'un immeuble : tu as des caméras, des registres, des fiches de présence. La sécurité commence par savoir lire ces informations.

---

## 1. Processus : `ps` et `/proc`

### `ps` : Lister les processus

`ps` (Process Status) affiche un instantané des processus en cours d'exécution.

```bash
ps -eo pid,pcpu,comm --sort=-pcpu

```text

| Option | Signification |
| --- | --- |
| `-e` | Tous les processus (pas seulement ceux de l'utilisateur courant) |
| `-o pid,pcpu,comm` | Afficher : PID, % CPU, nom de la commande |
| `--sort=-pcpu` | Trier par CPU décroissant (le plus gourmand en premier) |

**Trouver le processus le plus gourmand :**

```bash
ps -eo pid,pcpu,comm --sort=-pcpu | awk 'NR==2{print $1, $3}'

```text

`NR==2` : la deuxième ligne (la première est l'en-tête, la deuxième est le processus le plus vorace).

### `/proc` : Le système de fichiers virtuel

`/proc` n'est pas un vrai répertoire sur le disque : c'est une **fenêtre sur le noyau**. Chaque processus a son propre répertoire `/proc/<PID>/` contenant ses informations en temps réel.

```bash
/proc/1234/environ    # variables d'environnement du processus 1234
/proc/1234/cmdline    # ligne de commande complète
/proc/1234/status     # état, mémoire, UID...
/proc/1234/fd/        # descripteurs de fichiers ouverts

```text

**Lire les variables d'environnement d'un processus :**

```bash
tr '\0' '\n' < /proc/$1/environ

```text

Les variables sont séparées par des octets nuls (`\0`). `tr '\0' '\n'` les remplace par des sauts de ligne pour les rendre lisibles.

**Pourquoi c'est utile en forensique ?** Un malware peut cacher ses arguments dans ses variables d'environnement. Lire `/proc/<PID>/environ` révèle des tokens, des clés d'API, ou des chemins suspects injectés au démarrage.

### États des processus

| État | Lettre | Signification |
| --- | --- | --- |
| Running | `R` | En cours d'exécution ou prêt à tourner |
| Sleeping | `S` | Attend un événement (entrée/sortie...) |
| Zombie | `Z` | Terminé mais pas encore "récupéré" par son parent |
| Stopped | `T` | Suspendu par un signal |
| Disk sleep | `D` | Attente bloquante d'I/O (ininterruptible) |

### Processus zombies

Un processus zombie est un processus **terminé** dont le parent n'a pas encore lu le code de retour. C'est comme une lettre de démission envoyée mais pas encore lue par le manager : le processus est parti, mais son entrée reste dans la table des processus.

```bash
ps -eo pid,state | awk '$2 == "Z" {print $1}'

```text

Les zombies en eux-mêmes sont inoffensifs, mais un grand nombre révèle un problème dans le programme parent.

### Hiérarchie des processus

Chaque processus a un **parent** (PPID : Parent Process ID). Cette hiérarchie forme un arbre depuis `init` (PID 1) ou `systemd`.

```bash
ps -p $1 -o ppid= | tr -d ' '

```text

`-o ppid=` : afficher seulement le PPID (le `=` supprime l'en-tête de colonne).
`tr -d ' '` : supprimer les espaces en trop.

**Pourquoi c'est important en sécurité ?** Un shell spawné par Apache (`bash` dont le parent est `apache2`) est suspect : ça ressemble à un exploit web qui a lancé un reverse shell.

---

## 2. Signaux : Contrôler les processus

Linux communique avec les processus via des **signaux** : des messages courts envoyés par le noyau ou d'autres processus.

```bash
kill -<signal> <PID>

```text

`kill` est mal nommé : il n'arrête pas forcément le processus, il envoie juste un signal.

| Signal | Numéro | Nom | Comportement par défaut |
| --- | --- | --- | --- |
| SIGTERM | 15 | Terminate | Demande gentiment d'arrêter (le processus peut ignorer) |
| SIGKILL | 9 | Kill | Force l'arrêt immédiat : **impossible à ignorer** |
| SIGSTOP | 19 | Stop | Suspend le processus (comme une pause) |
| SIGCONT | 18 | Continue | Reprend un processus suspendu |

```bash
kill -15 $1       # SIGTERM : demande d'arrêt propre
kill -9 $1        # SIGKILL : arrêt forcé immédiat
kill -SIGSTOP $1  # Geler le processus

```text

**Quand utiliser SIGKILL ?** Seulement quand SIGTERM ne répond pas. SIGTERM permet au processus de se terminer proprement (fermer les fichiers, sauvegarder l'état). SIGKILL ne lui laisse aucune chance : mais il ne peut pas être ignoré.

---

## 3. Ports et sockets : `ss` et `lsof`

### `ss` : Socket Statistics

`ss` est le successeur de `netstat`. Il affiche les sockets réseau ouverts.

```bash
ss -lnt4

```text

| Option | Signification |
| --- | --- |
| `-l` | Listening : sockets en écoute uniquement |
| `-n` | Numérique : afficher les ports, pas les noms de service |
| `-t` | TCP seulement |
| `-4` | IPv4 seulement |

**Extraire les numéros de ports en écoute :**

```bash
ss -lnt4 | awk 'NR>1{split($4,a,":"); print a[2]}' | sort -n

```text

La colonne `$4` contient `0.0.0.0:22` ou `127.0.0.1:3306`. `split($4, a, ":")` découpe sur `:` et `a[2]` est le numéro de port.

### `lsof` : List Open Files

`lsof` liste **tous les fichiers ouverts** par tous les processus : et sous Linux, tout est fichier : fichiers réguliers, sockets réseau, pipes...

```bash
lsof -iTCP:$1 -sTCP:LISTEN -n -P

```text

| Option | Signification |
| --- | --- |
| `-iTCP:80` | Filtrer les connexions TCP sur le port 80 |
| `-sTCP:LISTEN` | Seulement les sockets en état d'écoute |
| `-n` | Ne pas résoudre les noms d'hôtes |
| `-P` | Ne pas résoudre les noms de services |

**Trouver quel programme écoute sur un port :**

```bash
lsof -iTCP:$1 -sTCP:LISTEN -n -P | awk 'NR==2{print $1}'

```text

La deuxième ligne (NR==2) est le premier résultat réel. `$1` est la colonne COMMAND.

---

## 4. Logs : Lire et analyser

### Structure des logs syslog

Les fichiers de log comme `/var/log/syslog` ou `/var/log/auth.log` suivent un format standard :

```text
Feb  3 16:10:45 hostname sshd[1234]: Accepted publickey for student from 10.0.0.1
  $1    $2  $3     $4       $5                     message

```text

Les trois premiers champs sont le timestamp : mois, jour, heure (`HH:MM:SS`).

### Filtrer les logs par plage horaire

```bash
START=$(date --date="30 minutes ago" +"%H:%M:%S")
awk -v start="$START" '$3 >= start && /sshd/' "$1"

```text

- `date --date="30 minutes ago"` : calcule l'heure d'il y a 30 minutes

- `-v start="$START"` : passe la variable shell à awk

- `$3 >= start` : compare le champ timestamp

- `&& /sshd/` : filtre uniquement les lignes contenant "sshd"

**Pourquoi c'est utile ?** Après un incident, on cherche à construire une timeline. "Qu'est-ce qui s'est passé sur SSH dans les 30 dernières minutes avant l'alerte ?"

### Logs kernel : Segfaults

```bash
grep segfault "$1"

```text

Un **segfault** (segmentation fault) indique qu'un processus a tenté d'accéder à une zone mémoire interdite. En sécurité, c'est souvent le signe d'un **exploit en cours** : une tentative de buffer overflow ratée génère un segfault avant (parfois) de réussir.

Un pic soudain de segfaults pour un même service = indicateur d'attaque.

---

## 5. Identifier le propriétaire d'un processus

```bash
ps -p $1 -o user=

```text

`-o user=` : afficher l'utilisateur qui a lancé le processus (le `=` supprime l'en-tête).

**Pourquoi ?** Un processus `bash` tourné par `www-data` est anormal : le serveur web ne devrait pas ouvrir de shell. C'est le signe classique d'une exploitation réussie.

---

## 6. Récap des commandes essentielles

```bash
# Processus le plus gourmand en CPU
ps -eo pid,pcpu,comm --sort=-pcpu | awk 'NR==2{print $1, $3}'

# Variables d'environnement d'un processus
tr '\0' '\n' < /proc/<PID>/environ

# Processus zombies
ps -eo pid,state | awk '$2 == "Z" {print $1}'

# Parent d'un processus
ps -p <PID> -o ppid= | tr -d ' '

# Ports en écoute (TCP IPv4)
ss -lnt4 | awk 'NR>1{split($4,a,":"); print a[2]}' | sort -n

# Qui écoute sur le port 80 ?
lsof -iTCP:80 -sTCP:LISTEN -n -P | awk 'NR==2{print $1}'

# Utilisateur d'un processus
ps -p <PID> -o user=

# Logs SSH des 30 dernières minutes
START=$(date --date="30 minutes ago" +"%H:%M:%S")
awk -v start="$START" '$3 >= start && /sshd/' /var/log/auth.log

# Segfaults dans les logs kernel
grep segfault /var/log/kern.log

```text
