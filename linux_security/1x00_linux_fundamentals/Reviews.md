# Reviews — Linux Fundamentals

Questions de révision typiques en entretien d'embauche. À maîtriser sans documentation.

---

## 9. Le piège du `chmod 777`

**Pourquoi `chmod 777` est-il considéré comme une vulnérabilité de sécurité, même sur un serveur privé ?**

`chmod 777` accorde toutes les permissions (lecture, écriture, exécution) à **tous les utilisateurs** du système, sans exception. Cela pose plusieurs problèmes :

- **Aucune isolation** : n'importe quel utilisateur peut lire, modifier ou supprimer le fichier sans que le propriétaire en soit informé.
- **Un serveur privé n'est jamais mono-utilisateur** : services, daemons, comptes applicatifs partagent la même machine. La compromission d'un seul compte (via phishing, par exemple) suffit à exposer l'ensemble du système.
- **Risque d'écrasement involontaire** : un processus tournant sous un autre compte peut écraser un fichier critique, y compris des fichiers nécessitant normalement les droits root.

> **Règle :** appliquer le principe du moindre privilège — donner uniquement les permissions strictement nécessaires, à personne de plus que nécessaire.

---

## 10. Le bit `x` sur un répertoire

**Contexte :** un répertoire `/data` a les permissions `r--`. À l'intérieur se trouve `secret.txt`, lisible par tous.

| Action | Possible ? | Explication |
| --- | --- | --- |
| `cd /data` | Non | Le bit `x` est requis pour *traverser* un répertoire. Sans lui : `Permission denied`. |
| `ls /data` | Non | Lister le contenu nécessite également le bit `x` en plus du `r`. |
| `cat /data/secret.txt` | Non | Accéder à un fichier dans un répertoire implique de le *traverser* : le bit `x` est obligatoire. |

**Conclusion :** le bit `x` sur un répertoire n'est pas un bit d'exécution au sens programme — c'est un bit de **traversée**. Sans lui, il est impossible d'accéder à quoi que ce soit à l'intérieur, qu'importe les permissions du fichier lui-même.

---

## 11. Le SUID sur un éditeur de texte

**Pourquoi est-il extrêmement dangereux de placer le bit SUID (`u+s`) sur un éditeur comme `vim` ou `nano` ?**

- **Le SUID est pleinement effectif sur les binaires compilés** : contrairement aux scripts shell, les exécutables comme `vim` et `nano` supportent réellement le SUID. Quand le propriétaire est `root` et que le SUID est positionné, le binaire s'exécute avec l'**EUID 0** (root), quel que soit l'utilisateur qui le lance.
- **Accès root sans authentification** : n'importe quel utilisateur du système peut lancer l'éditeur et opérer avec les privilèges root — sans mot de passe, sans `sudo`.
- **Échappement vers un shell** : `vim` permet d'exécuter des commandes shell directement depuis son interface (`:!bash`). Un utilisateur peut ainsi obtenir un **shell root interactif** en quelques secondes.

> **Vérification :** `find /usr/bin -perm -4000 -type f` permet d'auditer les binaires SUID présents sur un système.

---

## 12. La précédence des groupes

**Contexte :** `bob` n'est pas `alice`, mais il est membre du groupe `devs`.

| Entité | Permissions |
| --- | --- |
| Propriétaire (`alice`) | `rwx` |
| Groupe (`devs`) | `---` |
| Autres | `r--` |

**Bob peut-il lire le fichier ?**

Non. Voici pourquoi :

1. **Bob est-il le propriétaire ?** Non — le propriétaire est `alice`. Les permissions `rwx` ne s'appliquent pas à lui.
2. **Bob est-il dans le groupe ?** Oui — il appartient à `devs`. Linux applique donc les permissions de groupe : `---`. **Aucune permission n'est accordée.**
3. Linux s'arrête à la première correspondance identité/groupe. Même si les `Others` ont `r--`, ces permissions ne s'appliquent **pas** à `bob` car il est déjà catégorisé comme membre du groupe.

> **Point clé :** Linux évalue les permissions dans l'ordre `owner → group → others` et s'arrête à la première correspondance. Appartenir à un groupe avec des permissions restrictives peut bloquer l'accès, même si `others` aurait permis la lecture.

---

## 13. L'utilité du Sticky Bit

**Dans un répertoire partagé comme `/tmp`, pourquoi le Sticky Bit (`+t`) est-il indispensable ?**

Sans le Sticky Bit, **tout utilisateur ayant le droit d'écriture sur un répertoire peut supprimer n'importe quel fichier qui s'y trouve**, y compris les fichiers appartenant à d'autres utilisateurs.

Avec `chmod +t` :

- Seul le **propriétaire du fichier** (ou root) peut le supprimer.
- Les autres utilisateurs peuvent toujours créer leurs propres fichiers, mais ne peuvent pas toucher à ceux des autres.

C'est exactement le comportement de `/tmp` : tout le monde peut y déposer des fichiers temporaires, mais personne ne peut supprimer les fichiers des autres.

```bash
ls -ld /tmp
# drwxrwxrwt  ...   /tmp
#          ^
#          Sticky Bit (affiché comme 't' à la place de 'x' pour others)
```

---

## 14. Le processus "unkillable" et les descripteurs de fichiers

**Vous avez supprimé un fichier de log avec `rm`, mais `df` montre que l'espace disque n'est pas libéré. Un processus écrit encore sur son descripteur de fichier. Comment trouver ce PID ?**

Sous Linux, `rm` supprime uniquement l'entrée dans le système de fichiers (le lien). Tant qu'un processus détient un **descripteur de fichier ouvert** vers ce fichier, le noyau maintient les données en mémoire et sur disque — l'espace n'est libéré qu'à la fermeture du dernier descripteur.

**Méthodes pour trouver le PID :**

```bash
# Via lsof : lister les fichiers supprimés encore ouverts
lsof | grep deleted | grep '\.log'

# Variante courte
lsof +L1

# Via /proc directement (sans lsof)
find /proc/*/fd -ls 2>/dev/null | grep deleted
```

`lsof` est un interpréteur du système de fichiers virtuel `/proc` exposé par le noyau. Il permet de voir tous les fichiers ouverts par tous les processus.

**Une fois le PID identifié :**

```bash
kill -9 <PID>
```

La terminaison du processus ferme ses descripteurs, et le noyau libère alors l'espace disque.

---

## 15. Le piège de l'octal — SUID sur un script

**Vous exécutez `chmod 4755 script.sh`. Que représente le `4` ? Que représente le `7` ? Le SUID fonctionnera-t-il réellement sur un script bash sous Linux moderne ?**

### Décomposition de `4755`

| Chiffre octal | Signification |
| --- | --- |
| `4` | Bit SUID — dit au noyau : *exécute ce fichier avec l'UID du propriétaire, pas celui de l'utilisateur courant* |
| `7` | Propriétaire : `rwx` (lecture + écriture + exécution) |
| `5` | Groupe : `r-x` (lecture + exécution) |
| `5` | Autres : `r-x` (lecture + exécution) |

### Le SUID est-il effectif sur un script bash ?

**Non.** C'est une décision de sécurité délibérée du noyau Linux.

Lorsque le noyau détecte qu'un fichier est un **script interprété** (la première ligne commence par `#!`), il ignore le bit SUID. La raison : un script est exécuté par un interpréteur (`/bin/bash`, `/usr/bin/python3`…). Si le SUID était honoré, n'importe quel utilisateur pourrait injecter du code via des variables d'environnement (`PATH`, `IFS`, `LD_PRELOAD`…), rendant l'exploitation triviale.

Le SUID est fiable **uniquement sur les binaires compilés** (C, C++, Go…) car le noyau les charge directement en mémoire, sans passer par un interpréteur susceptible d'être manipulé.
