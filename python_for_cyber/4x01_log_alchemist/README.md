# LogHunter

> *« Des données ! Des données ! Des données ! Je ne peux pas fabriquer de briques sans argile. »* — **Sherlock Holmes**

Dans le projet précédent, j'ai créé un outil pour analyser des identifiants
statiques. Ici, je vais analyser l'activité d'une infrastructure à partir de
ses logs.

Les logs sont comme le rythme cardiaque d'une infrastructure. Chaque attaque
laisse une trace. Mais une trace cachée dans 50 Go de texte ne sert pas à
grand-chose si elle n'est pas détectée.

Le but de ce projet est de transformer des logs bruts et désordonnés en
informations utiles pour la sécurité. Je vais apprendre à traiter de très
gros fichiers, rechercher des motifs avec des expressions régulières,
détecter des attaques et relier plusieurs événements entre eux.

## Pourquoi ce projet est important

Les logs sont souvent très nombreux et difficiles à analyser manuellement.
La commande `grep` peut suffire pour un petit fichier, mais elle devient moins
pratique lorsqu'un grand nombre de serveurs envoie des centaines de gigaoctets
de logs chaque jour.

Un outil automatisé peut lire, analyser et signaler les événements suspects
plus rapidement. C'est une compétence importante pour le **Threat Hunting**,
c'est-à-dire la recherche active de menaces dans un système.

## Contexte

### Le scénario

La ferme web de **Nexus Financial** subit plusieurs attaques. Le SOC reçoit
trop d'alertes et a besoin d'un outil pour analyser les logs plus rapidement.

Les fichiers fournis contiennent notamment des logs Apache, Nginx et Syslog.
Les attaques recherchées sont les suivantes :

- injections SQL ;
- XSS ;
- attaques par force brute ;
- scans et comportements automatisés.

### La mission

Je dois construire un outil appelé **LogHunter**. Ce n'est pas seulement un
script qui lit un fichier : c'est un moteur d'analyse de logs.

Il devra pouvoir :

1. lire de gros fichiers efficacement avec des générateurs ;
2. normaliser plusieurs formats de logs dans une structure commune ;
3. enrichir les données avec des informations supplémentaires ;
4. détecter des motifs d'attaque comme SQLi, XSS et la force brute ;
5. relier plusieurs événements, par exemple un scan suivi d'une exploitation ;
6. traiter les données à grande échelle avec le multiprocessing.

## Fonctionnement général

### 1. Les données d'entrée

Le programme reçoit un fichier de logs mélangé, par exemple :

```text
192.168.1.5 - - [10/Oct/2023:13:55:36] "GET /admin.php" 404 1024
10.0.0.1 - - [10/Oct/2023:13:56:00] "GET /?id=1' OR '1'='1" 200 500
Jan 10 14:00:01 server1 sshd[123]: Failed password for root from 1.2.3.4
```

### 2. Le moteur

LogHunter lit les logs en flux, les normalise, les enrichit, les filtre,
détecte les attaques et corrèle les événements.

### 3. Le résultat

Le programme produit un rapport JSON structuré qui identifie les attaquants
et les méthodes utilisées.

## Objectifs d'apprentissage

À la fin du projet, je devrais être capable d'expliquer :

- comment utiliser les générateurs Python pour traiter des fichiers plus gros
  que la mémoire disponible ;
- comment écrire, déboguer et améliorer des expressions régulières complexes ;
- pourquoi la normalisation des données est importante pour analyser des logs ;
- comment détecter des bots, des injections SQL, du XSS et de la force brute ;
- comment détecter des pics d'activité et des attaques en plusieurs étapes ;
- comment analyser des logs comme un flux continu, à la manière d'un SIEM ;
- comment produire des rapports de sécurité structurés ;
- comment utiliser le multiprocessing pour les tâches qui utilisent beaucoup
  le processeur, comme l'analyse de nombreuses expressions régulières.

## Ressources

- [Python Generators (Real Python)](https://intranet.hbtn.io/rltoken/CDo6Wd310wjDKXOhDhCZ5A)
- [Regex101](https://intranet.hbtn.io/rltoken/J5FeskmFrtCS48uBdI26cw)
- [Apache Log Format](https://intranet.hbtn.io/rltoken/FPRF7E-myxC3gGO2Qf2-TA)
- [Documentation du module `re`](https://intranet.hbtn.io/rltoken/TZy4bbCUrwBfdSvQNTG8sQ)
- [Python Multiprocessing](https://intranet.hbtn.io/rltoken/6F1frtm-GcInca4elsRPVg)

Pour consulter l'aide intégrée de Python :

```bash
python3 -m pydoc re
python3 -m pydoc collections
```

## Prérequis

### Règles générales

- Les scripts sont testés sur Kali Linux, ParrotOS ou Ubuntu.
- Les éditeurs autorisés sont `vi`, `vim`, `emacs` et `vscode`.
- Tous les scripts doivent être exécutables et se terminer par une nouvelle
  ligne.
- La première ligne de chaque fichier Python doit être exactement :
  `#!/usr/bin/env python3`.
- Les noms de variables, fonctions et classes doivent être compréhensibles.
- Chaque module, fonction publique et classe doit être documenté.
- Les erreurs prévisibles doivent être gérées avec `try` et `except`.
- Le code doit respecter `pycodestyle`.
- Le développement doit être réalisé dans un environnement virtuel `venv`.
- Les annotations de type doivent être utilisées lorsque cela est pertinent.
- Le programme doit gérer les erreurs proprement.

### Règles particulières

- Le programme doit rester efficace avec des fichiers de plus de 100 Mo.
- Le module `re` doit être utilisé pour analyser les logs.
- `split()` ne doit pas être utilisé pour parser les logs, car cette méthode
  est trop fragile lorsque le format change.

## Génération des fichiers de test

Le script `generate_test_logs.py` permet de créer un fichier de logs de test.

```bash
chmod +x generate_test_logs.py
./generate_test_logs.py -o huge_access.log
```

Quelques exemples :

| Objectif | Commande |
| --- | --- |
| Petit jeu de données | `./generate_test_logs.py -o huge_access.log --lines 5000` |
| Résultat reproductible | `./generate_test_logs.py -o huge_access.log --lines 5000 --seed 42` |
| Date de départ précise | `./generate_test_logs.py -o huge_access.log --lines 5000 --start 2026-02-11T08:00:00+00:00` |
| Modifier la proportion de Syslog | `./generate_test_logs.py -o huge_access.log --lines 5000 --ratio-syslog 0.35` |

## Vérifications rapides

```bash
wc -l huge_access.log
grep -n "sqlmap\|UNION SELECT\|<script>\|Failed password\| 401 " -m 10 huge_access.log
```
