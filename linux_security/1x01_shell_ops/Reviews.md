# Reviews — Shell Ops

Questions de révision typiques en entretien d'embauche. À maîtriser sans documentation.

---

## 12. `grep` vs `awk`

**Quand utiliser `grep` plutôt que `awk` ? Quel est le rôle principal de chacun ?**

### `grep` — Filtrer des lignes

`grep` cherche les lignes qui **correspondent à un pattern** et les affiche. Son rôle est la **sélection** : inclure ou exclure des lignes.

```bash
# Trouver tous les utilisateurs dont le shell est /bin/bash
grep "/bin/bash" /etc/passwd
```

### `awk` — Traiter et extraire des champs

`awk` traite chaque ligne comme un ensemble de **champs** et permet d'appliquer une logique conditionnelle, des calculs ou des reformatages.

```bash
# Afficher le nom d'utilisateur (champ 1) et l'UID (champ 3)
awk -F: '{print $1, $3}' /etc/passwd
```

### Quand choisir l'un plutôt que l'autre ?

| Besoin | Outil adapté |
| --- | --- |
| Trouver des lignes contenant un pattern | `grep` |
| Extraire une colonne précise | `awk` |
| Filtrer ET reformater | `awk` |
| Simple présence/absence (code de retour) | `grep` |

> **Règle :** `grep` sélectionne, `awk` transforme. Ils sont souvent complémentaires dans un pipeline : `grep "ERROR" syslog | awk '{print $3}'`.

---

## 13. La puissance du Pipe — UUOC

**Ces deux commandes produisent-elles le même résultat ? Sont-elles équivalentes en efficacité ?**

```bash
# Commande A
cat file.txt | grep "Error"

# Commande B
grep "Error" file.txt
```

### Sortie identique, efficacité différente

Les deux commandes produisent **le même output**. Cependant :

- La commande A lance **deux processus** (`cat` + `grep`) et crée un pipe entre eux, alors que `grep` peut directement lire le fichier.
- La commande B est plus performante : `grep` ouvre et lit le fichier lui-même, sans processus intermédiaire.

Ce pattern s'appelle **UUOC — Useless Use Of Cat**. C'est une erreur courante chez les débutants.

### Quand le pipe est-il justifié ?

Le pipe est **indispensable** lorsque la source n'est pas un fichier mais le résultat d'une autre commande :

```bash
# Ici, le pipe est obligatoire
ps aux | grep "nginx"
journalctl -u nginx | grep "Error"
```

> **Règle :** si `grep` peut recevoir le fichier directement en argument, ne pas utiliser `cat`. Réserver le pipe aux cas où la source est dynamique.

---

## 14. Les Ancres Regex

**Pourquoi `grep "admin"` est-il potentiellement dangereux dans un fichier de logs ? Comment corriger cela ?**

### Le problème : correspondances non voulues

`grep "admin"` va retourner **toutes les lignes contenant la chaîne `admin`**, y compris :

- `superadmin`
- `administrator`
- `admin_panel`
- Des lignes contenant des informations d'état ou de session liées à ces comptes

On risque ainsi d'afficher des données sensibles sans le vouloir, ou d'obtenir des faux positifs qui faussent l'analyse.

### La solution : les ancres regex

```bash
# Correspond uniquement à la ligne contenant exactement "admin"
grep "^admin$" file.log

# Correspond au mot "admin" entouré de délimiteurs de mot
grep "\badmin\b" file.log
```

| Ancre | Signification |
| --- | --- |
| `^` | Début de ligne |
| `$` | Fin de ligne |
| `\b` | Délimiteur de mot (word boundary) |

> **Bonne pratique :** dans un contexte de sécurité, toujours être précis dans les patterns de recherche. Un `grep` trop large peut exposer des informations sensibles ou générer du bruit dans les résultats d'audit.

---

## 15. `sort` avant `uniq`

**Pourquoi faut-il toujours exécuter `sort` avant `uniq` ? Que se passe-t-il sinon ?**

`uniq` ne supprime que les **doublons adjacents** — les lignes identiques qui se suivent directement. Si le fichier n'est pas trié, des doublons non consécutifs ne seront pas détectés.

### Exemple concret

```text
Fichier original : a, b, a
```

| Commande | Résultat | Correct ? |
| --- | --- | --- |
| `uniq fichier` | `a, b, a` | Non — le doublon `a` n'est pas supprimé |
| `sort fichier \| uniq` | `a, b` | Oui — `sort` regroupe les `a`, puis `uniq` déduplique |

```bash
# Pipeline correct
sort fichier.txt | uniq -c | sort -rn
```

> **Note :** `sort -u` est un raccourci qui effectue le tri ET la déduplication en une seule commande.

---

## 16. Le Code de Retour `$?`

**Que vaut `$?` dans les cas suivants ?**

`$?` contient le **code de retour de la dernière commande exécutée**. Par convention Unix :

- `0` = succès
- `1` (ou tout autre valeur non nulle) = échec

### A. `grep "root" /etc/passwd` — correspondance trouvée

```text
$? = 0
```

`grep` a trouvé au moins une ligne correspondante : succès.

### B. `grep "nonexistent_user" /etc/passwd` — aucune correspondance

```text
$? = 1
```

`grep` n'a rien trouvé : il retourne 1 pour signaler l'absence de résultat.

### C. Pourquoi c'est critique dans les scripts bash ?

Contrairement à Python où `if` évalue une expression booléenne, **bash exécute une commande et regarde son code de retour** :

```bash
# bash : if exécute grep et teste son code de retour
if grep -q "root" /etc/passwd; then
    echo "L'utilisateur root existe"
fi
```

Toute la logique conditionnelle bash repose sur ce mécanisme. Des outils comme `&&`, `||` et `if` s'appuient tous sur `$?` pour décider de la suite de l'exécution.

> **Conseil :** utiliser `set -e` en début de script pour faire échouer automatiquement le script si une commande retourne un code non-nul — évite de continuer silencieusement après une erreur.

---

## 17. Guillemets simples vs doubles

**Contexte :**

```bash
VAR="World"
```

| Commande | Sortie |
| --- | --- |
| `echo "Hello $VAR"` | `Hello World` |
| `echo 'Hello $VAR'` | `Hello $VAR` |

### Pourquoi ce comportement ?

Le shell interprète différemment les deux types de guillemets :

- **Guillemets doubles `"..."` :** le shell **interprète** les variables (`$VAR`), les substitutions de commandes (`` `cmd` `` ou `$(cmd)`) et les séquences d'échappement (`\n`, `\t`…).
- **Guillemets simples `'...'` :** tout le contenu est traité **littéralement**. Aucune variable n'est développée, aucun caractère spécial n'est interprété.

```bash
VAR="World"
echo "Hello $VAR"    # Hello World  → $VAR est remplacé par sa valeur
echo 'Hello $VAR'    # Hello $VAR   → $VAR est affiché tel quel
echo "It's fine"     # It's fine    → l'apostrophe est ok dans les doubles
echo '$VAR is: '"$VAR"  # $VAR is: World → combinaison des deux styles
```

> **Règle pratique :** utiliser les guillemets doubles par défaut (ils protègent des espaces et des caractères spéciaux tout en permettant les variables). Réserver les guillemets simples pour les chaînes devant être traitées littéralement, comme les patterns `sed` ou `awk`.
