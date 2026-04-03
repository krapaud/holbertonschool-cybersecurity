# Identity Management — Mini-cours

> **Dépôt :** holbertonschool-cybersecurity
> **Répertoire :** `linux_security/1x02_identity_management`

---

## 0. The Ghost User Hunter — Détecter les comptes root cachés

### Commandes clés : `awk`, `/etc/passwd`

#### Structure de `/etc/passwd`

Chaque ligne de `/etc/passwd` suit ce format :

```text
username:password:UID:GID:comment:home:shell
   $1       $2    $3  $4    $5     $6    $7
```

Le **UID** (User ID) est le chiffre qui détermine les droits réels. Le noyau Linux ne connaît pas les noms — il ne raisonne qu'en UIDs. Un compte avec UID 0 **est** root, quel que soit son nom.

#### Technique de persistance : le faux utilisateur root

Un attaquant crée un compte anodin (`backup`, `support`) et modifie son UID à 0 dans `/etc/passwd`. Ce compte dispose des pleins pouvoirs root et passe souvent inaperçu lors d'une revue rapide.

```bash
awk -F: '$3 == 0 && $1 != "root" {print $1}' "$1"
```

| Élément | Signification |
| --- | --- |
| `-F:` | Délimiteur de champ `:` |
| `$3 == 0` | UID = 0 |
| `$1 != "root"` | Exclut le compte root légitime |
| `{print $1}` | Affiche uniquement le nom d'utilisateur |

> **Audit :** vérifier régulièrement qu'un seul compte possède l'UID 0 est l'une des premières vérifications d'un audit CIS Benchmark.

**Fichiers :** `0-audit_uid.sh`, `0-flag.txt`

---

## 1. The Service Shells — Comptes de service avec shell interactif

### Commandes clés : `awk`, filtrage par UID et shell

#### Pourquoi les comptes de service ne doivent pas avoir de shell

Les comptes de service (`www-data`, `nobody`, `bin`) ont un UID < 1000 et ne sont pas censés se connecter interactivement. Leur shell devrait être `/usr/sbin/nologin` ou `/bin/false`, qui bloquent toute connexion.

Si un développeur leur attribue `/bin/bash` "pour déboguer", une exploitation de service (faille Apache, injection, etc.) donne à l'attaquant un **shell interactif complet** au lieu d'être bloquée.

```bash
awk -F: '$3 < 1000 && $1 != "root" && $7 ~ /(sh|bash)$/ {print $1}' "$1"
```

| Condition | Signification |
| --- | --- |
| `$3 < 1000` | Compte système (UID < 1000) |
| `$1 != "root"` | Exclut root |
| `$7 ~ /(sh\|bash)$/` | Shell se terminant par `sh` ou `bash` |

> **Règle :** tout compte de service doit avoir `nologin` ou `false` comme shell. Vérifiable avec `grep -v nologin /etc/passwd | awk -F: '$3 < 1000'`.

**Fichiers :** `1-audit_shells.sh`, `1-flag.txt`

---

## 2. The Dangerous Groups — Audit des appartenances à risque

### Commandes clés : `awk`, `id`, `grep -w`

#### Groupes à privilèges élevés

Certains groupes confèrent des capabilities quasi-root sans sudo explicite :

| Groupe | Risque |
| --- | --- |
| `sudo` | Exécution de n'importe quelle commande en root |
| `docker` | Montage du système hôte, évasion vers root triviale |
| `disk` | Lecture brute du disque, y compris `/etc/shadow` |
| `shadow` | Lecture directe des hashes de mots de passe |

#### Stratégie d'audit

```bash
while IFS=: read -r user _ uid _; do
    if [[ "$uid" -ge 1000 ]]; then
        for group in disk docker shadow; do
            if id "$user" 2>/dev/null | grep -qw "$group"; then
                echo "$user:$group"
            fi
        done
    fi
done < "$1"
```

La commande `id <user>` retourne tous les groupes d'un utilisateur. `grep -qw` (quiet + word boundary) évite les faux positifs : `shadow` ne doit pas matcher `shadowsocks`.

> **Principe :** un utilisateur standard dans le groupe `docker` peut lancer `docker run -v /:/mnt --rm -it alpine chroot /mnt sh` et obtenir un shell root sur l'hôte en quelques secondes.

**Fichiers :** `2-audit_groups.sh`, `2-flag.txt`

---

## 3. SSH Configuration — Durcissement de l'accès distant

### Commandes clés : `sed`, `sshd -t`, `systemctl reload`

#### Les trois directives fondamentales de sécurité SSH

| Directive | Valeur sécurisée | Risque si mal configuré |
| --- | --- | --- |
| `PermitRootLogin` | `no` | Connexion root directe sans traçabilité |
| `PasswordAuthentication` | `no` | Attaques par force brute possibles |
| `PubkeyAuthentication` | `yes` | Seule clé cryptographique acceptée |

#### Modification sécurisée de `sshd_config`

```bash
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$1"
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$1"
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$1"
```

#### Validation obligatoire avant rechargement

```bash
if sshd -t -f "$1"; then
    systemctl reload ssh
fi
```

`sshd -t` teste la syntaxe du fichier de configuration **sans rechargement**. Un fichier corrompu sans cette validation peut verrouiller l'accès au serveur — situation critique en production.

> **Règle d'or :** toujours valider avant de recharger SSH. Garder une session root ouverte en parallèle lors de toute modification.

**Fichiers :** `3-harden_ssh.sh`, `3-flag.txt`

---

## 4. Password Policy — PAM et la qualité des mots de passe

### Commandes clés : `apt-get`, `sed`, PAM

#### Qu'est-ce que PAM ?

**PAM** (Pluggable Authentication Modules) est le système d'authentification modulaire de Linux. Il intercepte les opérations d'authentification (`login`, `sudo`, `passwd`, etc.) et applique des politiques configurables.

Le module `pam_pwquality` (paquet `libpam-pwquality`) ajoute des contraintes de complexité lors du changement de mot de passe.

#### Configuration de la politique

Le fichier `/etc/pam.d/common-password` contrôle les règles appliquées par `passwd`. On y insère la ligne :

```text
password requisite pam_pwquality.so retry=3 minlen=12 minclass=3
```

| Paramètre | Signification |
| --- | --- |
| `requisite` | Échec immédiat si le module échoue |
| `retry=3` | 3 tentatives avant rejet |
| `minlen=12` | Longueur minimale : 12 caractères |
| `minclass=3` | Minimum 3 classes parmi : majuscule, minuscule, chiffre, spécial |

> **Attention :** `sed` doit remplacer la ligne existante `pam_pwquality.so` ou l'ajouter si absente, pour éviter les doublons qui cumuleraient les contraintes.

**Fichiers :** `4-pw_policy.sh`, `4-flag.txt`

---

## 5. Shadow Crypto Audit — Détecter les hashes obsolètes

### Commandes clés : `awk`, `/etc/shadow`, identifiants d'algorithmes

#### Structure de `/etc/shadow`

```text
username:$id$salt$hash:last_change:min:max:warn:inactive:expire
```

L'identifiant `$id$` indique l'algorithme de hachage utilisé :

| ID | Algorithme | Statut |
| --- | --- | --- |
| `$1$` | MD5 | **Cassé** — crackable en quelques minutes avec un GPU |
| `$5$` | SHA-256 | Acceptable |
| `$6$` | SHA-512 | Recommandé |
| `$y$` | yescrypt | Moderne, résistant aux attaques GPU |

#### Identifier les comptes MD5

```bash
awk -F: '$2 ~ /^\$1\$/ {print $1}' "$1"
```

Le pattern `^\$1\$` correspond au hash MD5 en début du champ password. Les `\$` échappent le `$` qui a une signification spéciale en regex.

> **Pourquoi MD5 est dangereux :** un hash MD5 moderne peut être cracké à 10+ milliards de tentatives par seconde avec un GPU grand public. Un dictionnaire de rockyou.txt (~14M mots) se teste en quelques secondes.

**Fichiers :** `5-audit_crypto.sh`, `5-flag.txt`

---

## 6. The Secure Onboarding — Création de compte sans mot de passe

### Commandes clés : `useradd`, `passwd -l`, `mkdir`, `chmod`, `chown`

#### Anti-pattern : envoyer un mot de passe temporaire par email

Envoyer un mot de passe par email est risqué :

- L'email transite en clair par défaut
- L'utilisateur peut ne jamais changer le mot de passe
- Le mot de passe peut être intercepté, forwardé, archivé

#### Pattern sécurisé : clé SSH dès la création

```bash
useradd -m "$1"
passwd -l "$1"

mkdir -p /home/"$1"/.ssh
chmod 700 /home/"$1"/.ssh
echo "$2" > /home/"$1"/.ssh/authorized_keys
chmod 600 /home/"$1"/.ssh/authorized_keys
chown -R "$1":"$1" /home/"$1"/.ssh
```

| Commande | Rôle |
| --- | --- |
| `useradd -m` | Crée le compte avec son répertoire home |
| `passwd -l` | **Verrouille** le mot de passe (préfixe `!` dans `/etc/shadow`) |
| `chmod 700 ~/.ssh` | Seul le propriétaire peut lire/écrire/traverser |
| `chmod 600 authorized_keys` | Seul le propriétaire peut lire/écrire |

> **Pourquoi les permissions `.ssh` sont critiques :** OpenSSH refuse d'utiliser `authorized_keys` si les permissions sont trop permissives (`group-writable` ou `world-writable`). C'est une protection contre la modification malveillante des clés autorisées.

**Fichiers :** `6-onboard.sh`, `6-flag.txt`

---

## 7. Least Privilege Sudo — Configuration granulaire de sudo

### Commandes clés : `sudoers`, `visudo -c`, `/etc/sudoers.d/`

#### Le principe du moindre privilège appliqué à sudo

Donner `ALL=(ALL) ALL` à un opérateur junior signifie qu'une compromission de son compte équivaut à une compromission root complète. Il faut restreindre précisément les commandes autorisées.

#### Structure d'une règle sudoers

```text
user  HOST=(run_as)  [NOPASSWD:]  commande1, commande2
```

```text
junior ALL=(root) /usr/bin/systemctl restart apache2, /usr/bin/journalctl
```

| Champ | Valeur | Signification |
| --- | --- | --- |
| `junior` | Username | L'utilisateur concerné |
| `ALL` | Host | Tous les hôtes |
| `(root)` | Run as | S'exécute en tant que root |
| Sans `NOPASSWD` | — | Le mot de passe est requis |

#### Validation obligatoire

```bash
echo "$1 ALL=(root) /usr/bin/systemctl restart apache2, /usr/bin/journalctl" \
    > /etc/sudoers.d/junior
chmod 440 /etc/sudoers.d/junior
visudo -c -f /etc/sudoers.d/junior
```

`visudo -c` vérifie la syntaxe du fichier sans l'ouvrir en édition. Un fichier sudoers syntaxiquement invalide peut bloquer **tous** les accès sudo sur le système.

> **Bonne pratique :** toujours utiliser `/etc/sudoers.d/` plutôt que de modifier directement `/etc/sudoers`. Les fichiers dans ce répertoire sont inclus automatiquement et facilitent l'audit et la maintenance.

**Fichiers :** `7-sudo_config.sh`, `7-flag.txt`
