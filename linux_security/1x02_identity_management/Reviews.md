# Reviews — Identity Management

Questions de révision typiques en entretien d'embauche. À maîtriser sans documentation.

---

## 8. Authentification vs Autorisation

**Quelle est la différence entre Authentification et Autorisation ? Donnez une définition de chacune et un exemple concret où un utilisateur réussit l'authentification mais échoue à l'autorisation.**

### Définitions

| Concept | Définition |
| --- | --- |
| **Authentification** | Processus qui vérifie l'*identité* d'un utilisateur (« Qui es-tu ? ») via ses credentials : mot de passe, clé SSH, certificat… |
| **Autorisation** | Processus qui détermine ce que l'utilisateur *est autorisé à faire* une fois son identité confirmée (« Qu'as-tu le droit de faire ? ») |

### Exemple concret

Un développeur se connecte en SSH avec succès via sa clé — c'est l'**authentification** réussie. Il tente ensuite de lire `/etc/shadow` :

```bash
cat /etc/shadow
# Permission denied
```

L'accès est refusé car il n'est pas root — c'est l'**autorisation** qui échoue. Son identité est reconnue, mais ses privilèges sont insuffisants.

> **Règle :** l'authentification et l'autorisation sont deux mécanismes distincts. Authentifier quelqu'un ne lui accorde aucun privilège automatiquement — c'est le contrôle d'accès (ACL, permissions, sudoers) qui définit ce qu'il peut faire.

---

## 9. `sudo -i` vs `sudo su`

**Pourquoi `sudo -i` est-il généralement préféré à `sudo su` ? Considérez : les variables d'environnement, la journalisation et le principe du moindre privilège.**

### Comparaison

| Critère | `sudo -i` | `sudo su` |
| --- | --- | --- |
| **Environnement** | Charge l'environnement *complet* de root (`HOME`, `PATH`, `.bashrc` root) | Hérite de l'environnement de l'utilisateur courant |
| **Journalisation** | Chaque commande est loguée dans le journal sudo | La session `su` n'est pas tracée commande par commande |
| **Traçabilité** | L'événement d'élévation est enregistré avec l'utilisateur d'origine | Difficile d'auditer ce qui a été fait en root |

### Quand utiliser `sudo -i` ?

`sudo -i` est utile pour des sessions root longues (déploiement, maintenance) où taper `sudo` avant chaque commande serait fastidieux. Il charge un environnement root prévisible et propre.

### Risque à garder en tête

Obtenir un shell root complet et illimité reste dangereux : une erreur dans cet état peut avoir des conséquences irréversibles. Pour des actions ponctuelles, préférer `sudo commande` qui limite la portée de l'élévation.

> **Principe :** `sudo -i` est plus sûr que `sudo su` en termes de traçabilité, mais tous deux doivent être réservés aux cas où une élévation prolongée est réellement nécessaire.

---

## 10. Le risque de `NOPASSWD: ALL`

**Un collègue a configuré sudoers ainsi :**

```text
junior_admin ALL=(ALL) NOPASSWD: ALL
```

**Expliquez pourquoi c'est un échec critique de sécurité. Quels scénarios d'attaque cela permet-il ?**

### Analyse de la mauvaise configuration

Cette ligne accorde à `junior_admin` :

- L'accès à **toutes les commandes** sur **tous les hôtes**
- En tant que **n'importe quel utilisateur** (dont root)
- **Sans mot de passe**

C'est fonctionnellement équivalent à donner un accès root permanent et non authentifié.

### Scénarios d'attaque

1. **Compromission de session** : si l'attaquant vole le token de session (vol de cookie, XSS, ou session SSH détournée), il hérite immédiatement des droits root complets sans aucune friction.

2. **Persistance** : l'attaquant peut créer son propre compte root, installer une backdoor, modifier `/etc/sudoers`, puis supprimer les traces.

3. **Ransomware / destruction** : chiffrement ou effacement de l'ensemble du système sans nécessiter d'élévation supplémentaire.

4. **Déplacement latéral** : avec les droits root, accès à toutes les clés SSH, tokens, et secrets stockés sur la machine.

> **Règle :** `NOPASSWD: ALL` ne devrait jamais apparaître dans une configuration de production. Restreindre sudo aux commandes strictement nécessaires et toujours exiger le mot de passe.

---

## 11. Les types de hash dans `/etc/shadow`

**Étant donné cette ligne de `/etc/shadow` :**

```text
alice:$6$G8xPfkLm$K3j...(truncated)...:19000:0:99999:7:::
```

**Que signifie `$6$` ? Pourquoi est-il critique que `/etc/shadow` ait les permissions `640` ou `600` même si les mots de passe sont hachés ?**

### Signification de `$6$`

`$6$` identifie l'algorithme de hachage utilisé : **SHA-512**. C'est l'algorithme recommandé sous Linux moderne.

| ID | Algorithme | Statut |
| --- | --- | --- |
| `$1$` | MD5 | Cassé — crackable en minutes |
| `$5$` | SHA-256 | Acceptable |
| `$6$` | SHA-512 | Recommandé |
| `$y$` | yescrypt | Moderne, résistant GPU |

### Pourquoi les permissions restent critiques même avec des hashes

Un attaquant ayant accès à `/etc/shadow` peut :

1. **Identifier les algorithmes faibles** : les comptes encore en `$1$` (MD5) sont des cibles prioritaires.
2. **Effectuer une attaque hors-ligne** : copier les hashes et les soumettre à un outil comme `hashcat` ou `john` sans limite de tentatives et sans alerte — contrairement à une attaque en ligne.
3. **Cibler les mots de passe réutilisés** : un mot de passe cracké sur ce serveur peut être testé sur d'autres services.

> **Permission correcte :** `600` (root uniquement) ou `640` (root + groupe `shadow`). Ne jamais laisser `/etc/shadow` world-readable.

---

## 12. L'escalade via `vim` sous sudo

**La configuration sudoers suivante est en place :**

```text
developer ALL=(root) /usr/bin/vim
```

**Comment cet utilisateur peut-il triviallement obtenir un shell root complet ? Quelle est la correction ?**

### Exploitation — GTFOBins

`vim` permet d'exécuter des commandes shell depuis son interface. Lancé avec `sudo`, ces commandes héritent des privilèges root :

```bash
sudo vim
# Dans vim :
:!/bin/bash
# → shell root interactif obtenu
```

L'utilisateur n'a pas besoin de connaître de faille — c'est une fonctionnalité documentée de vim, répertoriée sur [GTFOBins](https://gtfobins.github.io/gtfobins/vim/).

D'autres éditeurs (`nano`, `less`, `more`, `man`, `git`, `python`, `perl`…) permettent des escalades similaires.

### Correction

Ne jamais accorder `sudo` à un éditeur de texte, un interpréteur ou tout programme capable d'exécuter des commandes shell.

Si l'édition de fichiers root est nécessaire, créer un wrapper dédié :

```bash
# sudoers : autoriser uniquement la modification d'un fichier précis
developer ALL=(root) /usr/local/bin/edit-config
```

Où `edit-config` est un script qui ouvre uniquement le fichier cible avec des options sécurisées.

> **Réflexe :** avant d'accorder un accès sudo, consulter GTFOBins pour vérifier si le binaire autorisé permet une escalade.

---

## 13. Le compte verrouillé et SSH

**L'entrée `/etc/shadow` d'un utilisateur contient `!` dans le champ mot de passe :**

```text
svc_backup:!:19000:0:99999:7:::
```

**Cet utilisateur peut-il se connecter en SSH par mot de passe ? Par clé publique ? Expliquez la différence.**

### Connexion par mot de passe

**Non.** Le `!` dans le champ password indique que le compte est **verrouillé**. PAM (Pluggable Authentication Modules) refuse toute authentification par mot de passe pour ce compte — la tentative est rejetée immédiatement.

### Connexion par clé publique

**Oui, si une clé est configurée dans `~/.ssh/authorized_keys`.** L'authentification par clé publique est gérée directement par le démon SSH (`sshd`) et **ne passe pas par PAM** pour la vérification du mot de passe. Elle ne consulte pas `/etc/shadow`.

Le processus est uniquement cryptographique :

1. Le client prouve qu'il possède la clé privée correspondante
2. `sshd` vérifie dans `authorized_keys`
3. L'accès est accordé — indépendamment du statut du compte dans `/etc/shadow`

### Résumé

| Méthode | Consulte `/etc/shadow` ? | Bloqué par `!` ? |
| --- | --- | --- |
| Mot de passe SSH | Oui (via PAM) | Oui |
| Clé publique SSH | Non | Non |

> **Usage légitime :** verrouiller le mot de passe d'un compte de service (`passwd -l svc_backup`) tout en autorisant la connexion par clé SSH est la bonne pratique pour les comptes d'automatisation — comme vu en exercice 6.
