# Shell Ops — Mini-cours

> **Dépôt :** holbertonschool-cybersecurity  
> **Répertoire :** `linux_security/1x01_shell_ops`

---

## 0. Le Redirecteur Global — Gérer les descripteurs de fichiers

### Commandes clés : `exec`, `>>`, `2>&1`

En shell, chaque processus dispose de trois **descripteurs de fichiers** standards :

| Descripteur | Nom | Valeur |
| --- | --- | --- |
| `0` | stdin | Entrée standard |
| `1` | stdout | Sortie standard |
| `2` | stderr | Sortie d'erreur |

Ajouter `>> log.txt` à chaque `echo` est fastidieux. La bonne pratique est de rediriger **une seule fois** en début de script avec `exec` :

```bash
exec >> "$1" 2>&1
```

- `exec >> "$1"` : redirige stdout (descripteur 1) en mode ajout vers le fichier `$1`
- `2>&1` : redirige stderr (descripteur 2) vers la même destination que stdout

Tout ce qui suit dans le script — chaque `echo`, chaque commande — ira automatiquement dans le fichier sans aucune syntaxe supplémentaire.

```bash
#!/bin/bash
exec >> "$1" 2>&1
echo "Starting Task"
echo "Doing Work"
echo "Error: Work Failed" >&2
```

> **Note :** `>&2` sur la dernière ligne envoie explicitement vers stderr — qui est, après le `exec`, redirigé vers le fichier.

**Fichiers :** `0-logging.sh`, `0-flag.txt`

---

## 1. Pas de fichiers temporaires — La substitution de processus

### Commandes clés : `diff`, `<(...)`, substitution de processus

La substitution de processus (`<(commande)`) permet de passer la **sortie d'une commande comme si c'était un fichier**, sans créer de fichier temporaire sur le disque.

**Approche naïve (à éviter) :**

```bash
cut -d: -f1 /etc/passwd > a.txt
cut -d: -f1 /etc/passwd | sort > b.txt
diff a.txt b.txt
rm a.txt b.txt
```

**Approche propre avec la substitution de processus :**

```bash
diff <(cut -d: -f1 "$1") <(cut -d: -f1 "$1" | sort)
```

Le shell crée des pseudo-fichiers (sous `/dev/fd/`) pour chaque `<(...)` et les passe à `diff`. Aucun fichier temporaire n'est écrit sur le disque.

| Outil | Rôle |
| --- | --- |
| `cut -d: -f1` | Extrait la 1ère colonne (délimiteur `:`) |
| `sort` | Trie alphabétiquement |
| `diff <(A) <(B)` | Compare A et B comme deux fichiers |

**Fichiers :** `1-compare.sh`, `1-flag.txt`

---

## 2. Le Processeur en Masse — `find` et `xargs`

### Commandes clés : `find`, `xargs`, `mv`

Pour renommer des centaines de fichiers, une boucle `for` fonctionne mais `xargs` est plus robuste et efficace : il regroupe les arguments et gère les noms de fichiers avec des espaces via `-I {}`.

```bash
find "$1" -maxdepth 1 -name "*.log" | xargs -I {} mv {} {}.old
```

| Option | Signification |
| --- | --- |
| `-maxdepth 1` | Ne cherche que dans le répertoire courant, pas récursivement |
| `-name "*.log"` | Filtre les fichiers `.log` |
| `xargs -I {}` | Remplace `{}` par chaque ligne reçue en entrée |
| `mv {} {}.old` | Renomme `fichier.log` en `fichier.log.old` |

> **Avantage de `xargs`** : contrairement à une boucle `for $(ls ...)`, `xargs` gère correctement les noms contenant des espaces lorsqu'on utilise `-0` (avec `find -print0`).

**Fichiers :** `2-mass_rename.sh`, `2-flag.txt`

---

## 3. L'Anonymiseur — `sed` et les expressions régulières

### Commandes clés : `sed`, regex IPv4

`sed` (Stream EDitor) est un outil de transformation de texte ligne par ligne. Il applique des expressions régulières pour substituer, supprimer ou insérer du contenu.

#### Remplacer toutes les adresses IPv4

Une adresse IPv4 est composée de 4 octets (0-255) séparés par des points. En regex :

```text
[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}
```

```bash
sed 's/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/[REDACTED_IP]/g' "$1"
```

| Élément | Signification |
| --- | --- |
| `s/pattern/remplacement/g` | Substitution globale (toutes les occurrences sur la ligne) |
| `[0-9]\{1,3\}` | Entre 1 et 3 chiffres |
| `\.` | Point littéral (le `.` seul = n'importe quel caractère) |

> **Sécurité :** avant de partager un fichier de configuration, toujours vérifier l'absence d'IPs internes, credentials et chemins sensibles. `sed` est l'outil de choix pour la redaction automatisée.

**Fichiers :** `3-anonymize.sh`, `3-flag.txt`

---

## 4. Le Filtre Avancé — `awk` et la logique conditionnelle

### Commandes clés : `ls -l`, `awk`

`awk` est un langage de traitement de texte orienté colonnes. Il excelle pour filtrer des lignes selon des conditions sur leurs champs.

```bash
ls -l "$1" | awk 'NR>1 && $5 > 1024 {print $9}'
```

Décomposition de la sortie de `ls -l` :

```text
-rw-r--r-- 1 student student 5000 Feb 3 16:10 big_1.log
 $1        $2  $3      $4    $5   $6 $7  $8    $9
```

| Condition `awk` | Signification |
| --- | --- |
| `NR>1` | Ignore la première ligne (`total ...`) |
| `$5 > 1024` | La 5e colonne (taille en octets) dépasse 1024 |
| `{print $9}` | Affiche la 9e colonne (nom du fichier) |

> **Note :** analyser `ls -l` avec `awk` est pragmatique pour des analyses rapides. Pour des scripts de production robustes, préférer `find -size +1k` qui gère les cas limites (noms avec espaces, liens symboliques…).

**Fichiers :** `4-heavy_files.sh`, `4-flag.txt`

---

## 5. Le Nettoyeur d'Utilisateurs — Validation et gestion de comptes

### Commandes clés : `while read`, `id`, `usermod -L`

Ce script illustre le traitement ligne par ligne d'un fichier et la validation avant action — un principe fondamental en automatisation sécurisée.

```bash
while IFS= read -r username; do
    if id "$username" &>/dev/null; then
        usermod -L "$username"
        echo "User $username locked"
    else
        echo "User $username not found"
    fi
done < "$1"
```

| Élément | Signification |
| --- | --- |
| `while IFS= read -r` | Lit ligne par ligne sans altérer les espaces ni les backslashes |
| `id "$username"` | Vérifie l'existence de l'utilisateur |
| `&>/dev/null` | Supprime stdout et stderr (on ne veut que le code de retour) |
| `usermod -L` | Verrouille le compte (préfixe `!` dans `/etc/shadow`) |

> **Principe :** toujours valider l'existence avant d'agir. Un nom d'utilisateur inexistant dans `usermod` générerait une erreur et potentiellement interromprait le script.

**Fichiers :** `5-cleanup.sh`, `5-flag.txt`

---

## 6. L'Attente de Service — Boucle `until` et vérification de port

### Commandes clés : `until`, `nc` (netcat), `sleep`

En déploiement, il faut souvent attendre qu'un service soit prêt avant de poursuivre. La boucle `until` exécute un bloc **tant que la condition est fausse**.

```bash
until nc -z "$1" 80 2>/dev/null; do
    echo "Waiting..."
    sleep 1
done
echo "Service UP!"
```

| Commande | Signification |
| --- | --- |
| `until <condition>` | Répète le bloc jusqu'à ce que la condition réussisse (code retour 0) |
| `nc -z host port` | Teste si le port est ouvert sans envoyer de données (`-z` = zero I/O) |
| `sleep 1` | Attend 1 seconde entre chaque tentative |

> **Alternative :** `curl -s http://localhost > /dev/null` ou `/dev/tcp/host/port` en bash pur si `nc` n'est pas disponible. Dans les pipelines CI/CD, des outils dédiés comme `wait-for-it.sh` ou `dockerize` sont préférés.

**Fichiers :** `6-wait_for.sh`, `6-flag.txt`

---

## 7. Le Rotateur de Logs — Automatisation de maintenance

### Commandes clés : `gzip`, `mv`, `-d`, `-f`, validation d'arguments

Ce script combine plusieurs compétences : validation d'arguments, création de répertoire, boucle sur des fichiers, condition sur la taille, compression.

```bash
#!/bin/bash
[[ ! -d "$1" ]] && exit 1

mkdir -p "$1/backups"

for logfile in "$1"/*.log; do
    [[ ! -f "$logfile" ]] && continue
    size=$(stat -c%s "$logfile")
    if [[ $size -gt 1024 ]]; then
        gzip "$logfile"
        mv "${logfile}.gz" "$1/backups/"
    else
        echo "Skipping small file: $(basename "$logfile")"
    fi
done
```

| Étape | Outil | Rôle |
| --- | --- | --- |
| Validation | `[[ ! -d "$1" ]]` | Vérifie que l'argument est un répertoire valide |
| Création | `mkdir -p` | Crée `backups/` sans erreur si déjà existant |
| Taille | `stat -c%s` | Retourne la taille du fichier en octets |
| Compression | `gzip` | Compresse en `.gz` (supprime l'original) |
| Déplacement | `mv` | Déplace l'archive vers `backups/` |

> **Logrotate vs script maison :** pour la production, `logrotate` (exercice 8 du module précédent) gère nativement la compression, la rotation et la rétention. Un script maison reste utile pour des cas personnalisés ou des environnements minimalistes.

**Fichiers :** `7-rotate.sh`, `7-flag.txt`
