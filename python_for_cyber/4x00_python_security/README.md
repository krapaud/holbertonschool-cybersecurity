# Python for Cybersecurity

## Fiche de cours

Ce projet présente les bases de Python appliquées à la cybersécurité : préparation d'un environnement isolé, analyse de données, détection et contrôles de sécurité.

## Conventions de fichiers

Les scripts exécutables doivent commencer par un shebang adapté à leur langage :

```python
#!/usr/bin/env python3
```

Pour un script Bash :

```bash
#!/bin/bash
```

Les scripts doivent être exécutables, les fichiers texte doivent se terminer par une nouvelle ligne et les dépendances doivent être déclarées dans `requirements.txt`.

## Task 0 : The Setup

### Objectif

Préparer un espace de travail Python propre et reproductible avant d'écrire du code de sécurité.

### Pourquoi utiliser un environnement virtuel ?

Un environnement virtuel isole les bibliothèques du projet du système et des autres projets. Cela évite les conflits de versions et permet d'installer les dépendances sans modifier globalement Python.

### Structure attendue

```text
4x00_python_security/
├── .gitignore
├── README.md
├── breach_check.py
├── requirements.txt
└── venv/
```

Le dossier `venv/` ne doit pas être versionné dans Git.

### Commandes utiles

Créer l'environnement :

```bash
python3 -m venv venv
```

L'activer :

```bash
source venv/bin/activate
```

Installer les dépendances :

```bash
pip install -r requirements.txt
```

Vérifier le style Python :

```bash
pycodestyle breach_check.py
```

### Fichiers importants

`requirements.txt` contient les dépendances du projet. Pour cette task, il doit contenir `pycodestyle`.

`.gitignore` doit exclure l'environnement virtuel et les caches Python, notamment `venv/`, `__pycache__/` et les fichiers compilés Python.

`breach_check.py` est le point d'entrée du projet. La task demande un message de démarrage exact afin de vérifier que le script est correctement initialisé.

### Erreurs fréquentes

- Installer `pycodestyle` globalement au lieu de l'installer dans `venv`.
- Oublier d'activer l'environnement avant d'installer les dépendances.
- Ajouter `venv/` ou `__pycache__/` à Git.
- Oublier le shebang ou utiliser un shebang qui ne correspond pas au langage.
- Modifier le texte du message de démarrage demandé.
- Oublier la nouvelle ligne finale des fichiers.

### Checklist Task 0

- [ ] L'environnement virtuel `venv/` existe.
- [ ] `pycodestyle` est installé dans `venv`.
- [ ] `requirements.txt` contient `pycodestyle`.
- [ ] `.gitignore` ignore `venv/`.
- [ ] `.gitignore` ignore les caches Python.
- [ ] `breach_check.py` contient le shebang Python adapté.
- [ ] `breach_check.py` contient le message exact demandé.
- [ ] `README.md` est présent et documente le projet.

## Évolution du cours

Cette fiche sera enrichie à chaque nouvelle task avec les notions, la méthode, les erreurs fréquentes et les contrôles associés.
