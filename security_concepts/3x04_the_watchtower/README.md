# The Watchtower

## Objectif du cursus

Ce projet introduit la surveillance de sécurité. Après avoir étudié les permissions et l'authentification, l'objectif est maintenant de savoir observer ce qui se passe sur les systèmes, conserver les preuves et détecter les comportements suspects.

Le contexte est celui de `DataFortress`, qui a subi une intrusion sur un serveur web. L'attaquant a supprimé les journaux locaux avant de partir. La mission consiste donc à construire une architecture de journalisation centralisée, analyser des traces et automatiser certaines détections.

## Les trois missions

1. Concevoir un serveur de logs centralisé afin que les journaux restent disponibles même après la compromission d'une machine.
2. Analyser des journaux bruts pour reconstituer une attaque.
3. Écrire des scripts qui signalent automatiquement des comportements suspects.

## Objectifs à maîtriser

- expliquer pourquoi les logs centralisés sont importants pour la forensique et la non-répudiation ;
- comprendre le rôle de `rsyslog` pour envoyer et recevoir des événements réseau ;
- reconnaître la structure de `auth.log`, `syslog` et `apache2/access.log` ;
- utiliser les expressions régulières pour extraire des adresses IP et des noms d'utilisateur ;
- distinguer un vrai positif d'un faux positif ;
- corréler plusieurs événements qui appartiennent au même scénario ;
- configurer `logrotate` pour éviter que les journaux remplissent le disque.

## Pourquoi la journalisation centralisée est importante

Un journal conservé uniquement sur la machine surveillée peut être supprimé ou modifié par un attaquant qui obtient suffisamment de privilèges. Une copie envoyée rapidement vers un serveur séparé rend cette suppression plus difficile et fournit une source utile pour l'enquête.

La centralisation améliore donc :

- la disponibilité des preuves ;
- la détection d'une activité anormale ;
- la comparaison des événements entre plusieurs machines ;
- l'attribution des actions à une machine ou à un compte ;
- la conformité et les audits.

La centralisation ne suffit pas seule. Il faut aussi protéger les droits d'accès, synchroniser l'heure, surveiller les pertes de messages et contrôler la conservation des données.

## Journaux Linux principaux

| Journal | Contenu général |
| --- | --- |
| `/var/log/auth.log` | Connexions, authentification SSH, utilisation de `sudo` |
| `/var/log/syslog` | Événements généraux des services et du système |
| `/var/log/kern.log` | Messages du noyau, pilotes et événements réseau bas niveau |
| `/var/log/apache2/access.log` | Requêtes reçues par un serveur Apache |

Le contenu et le chemin exact peuvent varier selon la distribution et la configuration. Il faut toujours lire l'énoncé et vérifier le format attendu avant d'écrire un script.

## `rsyslog`

`rsyslog` collecte, filtre, transforme et transmet des messages de journalisation.

Dans une architecture simple :

```text
Machine surveillée → transport réseau → serveur central → stockage protégé
```

Le serveur central doit écouter sur le protocole et le port prévus. Le pare-feu local doit autoriser uniquement le trafic nécessaire. Les règles de réception doivent enregistrer les messages dans un emplacement séparé et documenté.

Points à vérifier lors d'une configuration :

1. le service est installé et actif ;
2. le protocole choisi est cohérent côté émission et réception ;
3. le port d'écoute est bien ouvert ;
4. la règle de routage écrit au bon endroit ;
5. les permissions empêchent les utilisateurs non autorisés de modifier les logs ;
6. un test contrôlé confirme la réception d'un message.

## Lire un log avant de l'analyser

Pour chaque ligne, repérer progressivement :

```text
date et heure | machine | service | utilisateur ou IP | action | résultat
```

Ne pas interpréter une ligne isolée trop vite. Une erreur de connexion peut être normale, alors qu'une série d'échecs suivie d'une réussite depuis la même adresse peut être plus intéressante.

## Expressions régulières

Une expression régulière décrit un motif de texte. Elle peut servir à repérer une adresse IP, un nom d'utilisateur, un code HTTP ou une action précise.

Avant d'écrire un motif, identifier :

- le texte qui précède la valeur ;
- le format exact de la valeur ;
- le séparateur qui la suit ;
- les cas valides et les cas ambigus.

Une expression régulière simple n'est pas toujours une validation complète d'adresse IP. Pour un exercice, suivre le format des logs fourni et tester plusieurs exemples.

## Outils de traitement

- `grep` recherche des lignes qui correspondent à un motif ;
- `awk` découpe les colonnes et effectue des calculs ;
- `sed` transforme du texte ;
- `wc -l` compte les lignes ;
- `sort` ordonne les résultats ;
- `uniq` regroupe des valeurs répétées.

Pour combiner plusieurs outils, comprendre d'abord la sortie de chaque commande séparément. Cela rend le diagnostic plus simple et évite de produire une commande difficile à vérifier.

## Détection et qualité des alertes

Un `True Positive` est une alerte qui correspond réellement à une activité suspecte. Un `False Positive` est une alerte déclenchée alors que l'activité est légitime.

Une bonne règle de détection doit préciser :

1. l'événement recherché ;
2. la source de l'événement ;
3. le seuil ou la condition ;
4. la période d'observation ;
5. le résultat attendu ;
6. les cas légitimes qui pourraient déclencher l'alerte.

## Corrélation de logs

La corrélation consiste à relier plusieurs événements avec des éléments communs : adresse IP, nom d'utilisateur, machine, identifiant de session ou fenêtre temporelle.

Exemple de raisonnement :

```text
échecs SSH répétés → connexion réussie → commande sudo inhabituelle
```

Chaque événement pris séparément peut être insuffisant. Ensemble, ils peuvent révéler une chaîne d'attaque plus crédible.

## Rotation des logs

`logrotate` évite la saturation du disque en renommant, compressant et supprimant les anciens journaux selon une politique de conservation.

Une politique correcte doit définir :

- la fréquence de rotation ;
- le nombre d'archives conservées ;
- la compression ;
- la création d'un nouveau fichier avec les bonnes permissions ;
- le rechargement éventuel du service ;
- la conservation des preuves nécessaires à la forensique.

## Méthode de travail pour les scripts

Pour chaque tâche :

1. lire précisément le format de sortie demandé ;
2. identifier les fichiers et champs nécessaires ;
3. tester manuellement une commande simple ;
4. transformer progressivement cette commande en script ;
5. vérifier les fichiers absents, vides ou difficiles à lire ;
6. comparer la sortie caractère par caractère avec l'énoncé ;
7. vérifier la syntaxe et le droit d'exécution du script.

Pour la tâche `0-stats.sh`, commence par déterminer quelle commande compte les lignes d'un fichier. Ensuite, applique-la séparément aux trois chemins demandés et construis exactement les trois lignes de sortie imposées. La solution n'est pas fournie ici afin que tu puisses la réaliser toi-même.

## Règles de sécurité

Les fichiers d'attaque sont des preuves textuelles. Ils doivent être lus et analysés, mais jamais exécutés. Une commande trouvée dans un log doit rester une donnée, pas devenir une instruction à lancer.

## Ressources et commandes à consulter

```bash
man rsyslog.conf
man logger
man grep
man awk
```

Les scripts sont testés sur Ubuntu 20.04 ou une version ultérieure. Ils doivent commencer exactement par `#!/bin/bash`, être exécutables et se terminer par une nouvelle ligne.
