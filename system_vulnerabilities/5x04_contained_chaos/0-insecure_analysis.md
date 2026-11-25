# Analyse du Dockerfile vulnérable

## Contexte

Ce Dockerfile accumule des risques liés à l’image de base, aux paquets, aux
secrets, à la construction de l’image et à l’exécution du processus. Chaque
point ci-dessous décrit le défaut, son impact et un scénario d’exploitation.

## Problèmes de sécurité

### 1. Image de base `ubuntu:latest` non fixée

- **Problème :** `latest` est une étiquette modifiable qui ne garantit pas une version
  ni un contenu identique entre deux constructions.
- **Danger :** une reconstruction peut recevoir une version différente,
  introduire une régression ou modifier silencieusement les composants. Il est
  aussi plus difficile de reproduire et auditer l’image livrée.
- **Exploitation possible :** un attaquant qui compromet une chaîne de
  distribution ou profite d’une mise à jour compromise de l’étiquette peut faire
  construire une image contenant du code malveillant. Même sans attaque, la
  dérive de version peut réintroduire une vulnérabilité corrigée auparavant.

### 2. Paquets installés sans versions déterminées

- **Problème :** les versions des paquets installés par `apt-get` ne sont pas
  fixées.
- **Danger :** le contenu change au fil du temps et la construction devient
  moins reproductible. Une version vulnérable ou incompatible peut être
  intégrée sans changement du Dockerfile.
- **Exploitation possible :** un attaquant exploite une faille connue dans une
  version de paquet récupérée lors de la construction, puis utilise le service compromis
  comme point d’entrée dans l’application ou le réseau.

### 3. Cache APT conservé dans la couche de l’image

- **Problème :** le Dockerfile n’efface pas les listes APT après
  l’installation.
- **Danger :** cela augmente l’image et conserve des fichiers inutiles. Les
  données et outils supplémentaires compliquent l’inspection et peuvent
  révéler des détails sur les paquets disponibles.
- **Exploitation possible :** un acteur qui récupère l’image peut analyser les
  métadonnées et versions pour repérer des composants obsolètes et préparer
  des attaques ciblées.

### 4. Outils de développement installés dans l’image de production

- **Problème :** `gcc`, `make` et `python3-pip` sont présents avec
  l’application en production.
- **Danger :** ces outils augmentent la surface d’attaque et permettent de
  compiler ou installer du code directement après une compromission.
- **Exploitation possible :** après avoir obtenu une exécution de commandes
  dans l’application, un attaquant compile un exploit adapté au noyau ou
  installe un outil de post-exploitation dans le conteneur.

### 5. Outils réseau et de diagnostic superflus

- **Problème :** `curl`, `wget`, `net-tools` et `iputils-ping` sont ajoutés
  alors que l’image applicative n’en démontre pas le besoin.
- **Danger :** ces utilitaires aident à explorer le réseau, télécharger des
  charges utiles et communiquer avec des systèmes externes.
- **Exploitation possible :** un attaquant ayant compromis l’application
  utilise `curl` ou `wget` pour télécharger une charge utile, puis inspecte
  les interfaces et les routes pour se déplacer vers des services internes.

### 6. Éditeur interactif présent en production

- **Problème :** `vim` est installé dans l’image.
- **Danger :** un éditeur interactif offre un moyen pratique de lire ou
  modifier des fichiers et d’exécuter des commandes depuis une session
  compromise.
- **Exploitation possible :** avec un shell dans le conteneur, l’attaquant
  utilise l’éditeur pour examiner les configurations, modifier des fichiers
  applicatifs ou lancer des commandes auxiliaires.

### 7. `sudo` installé sans justification

- **Problème :** `sudo` est présent alors qu’aucun utilisateur non privilégié
  ni besoin d’élévation n’est défini.
- **Danger :** il ajoute un outil et des règles de délégation qui peuvent
  devenir un chemin d’escalade si une configuration permissive ou un défaut
  est exploitable.
- **Exploitation possible :** après une compromission d’un compte autorisé
  par une règle `sudoers` trop large, l’attaquant élève ses privilèges dans le
  conteneur.

### 8. Mot de passe root inscrit dans le Dockerfile

- **Problème :** `root:devstream123` est défini en clair pendant la
  construction.
- **Danger :** le mot de passe peut être retrouvé dans le dépôt, l’historique
  des couches ou le cache de build. Il est faible et réutilisable si d’autres
  environnements partagent ce secret.
- **Exploitation possible :** une personne ayant accès au dépôt ou à l’image
  extrait le mot de passe, puis tente de l’utiliser pour accéder à d’autres
  systèmes ou services de l’entreprise.

### 9. Identifiants de base de données intégrés via `ENV`

- **Problème :** l’hôte, le compte administrateur et le mot de passe de la base
  sont définis dans l’image avec des instructions `ENV`.
- **Danger :** ces valeurs sont visibles dans les métadonnées de l’image, par
  exemple avec `docker inspect`, et sont propagées aux conteneurs qui en
  dérivent. Le compte `admin` accorde vraisemblablement des privilèges élevés.
- **Exploitation possible :** un utilisateur qui peut récupérer l’image lit
  les variables, se connecte à la base interne et exfiltre ou modifie les
  données de production.

### 10. Copie de tout le contexte de construction

- **Problème :** `COPY . /app` copie le dépôt entier sans filtrage visible.
- **Danger :** des fichiers locaux, clés, fichiers `.env`, dépôts Git, caches,
  artefacts de test ou configurations peuvent être inclus accidentellement.
- **Exploitation possible :** un attaquant extrait l’image et récupère un
  secret oublié dans le contexte de construction, puis l’utilise pour accéder à un
  service ou à un compte de développeur.

### 11. Dépendances Python non verrouillées et non vérifiées

- **Problème :** `pip3 install -r requirements.txt` n’impose ni versions
  exactes ni vérification d’intégrité dans ce Dockerfile.
- **Danger :** un build futur peut installer une nouvelle version vulnérable,
  compromise ou incompatible. Le fichier de dépendances pourrait aussi
  contenir une dépendance malveillante ou une version trop permissive.
- **Exploitation possible :** une dépendance compromise est téléchargée durant
  le build et exécute du code avec les privilèges de l’application, permettant
  le vol de secrets ou l’installation d’une porte dérobée.

### 12. Installation et mise à jour APT sans nettoyage ni contrôle des erreurs

- **Problème :** l’installation est faite avec `apt-get update` et
  `apt-get install -y`, sans `--no-install-recommends`, nettoyage du cache ni
  mesure de réduction des composants.
- **Danger :** les paquets recommandés peuvent ajouter des composants
  inutiles; l’image devient plus grande et plus difficile à maintenir.
- **Exploitation possible :** un attaquant cible un composant secondaire
  installé par dépendance ou recommandé, puis s’en sert comme point d’entrée
  dans le conteneur.

### 13. Aucun utilisateur non privilégié n’est défini

- **Problème :** il n’y a pas d’instruction `USER`; le processus du conteneur
  s’exécute donc généralement en tant que root.
- **Danger :** une vulnérabilité d’exécution de code donne immédiatement les
  privilèges root à l’intérieur du conteneur. Une mauvaise configuration du
  runtime peut amplifier les conséquences sur l’hôte.
- **Exploitation possible :** un attaquant exploite une faille de l’application
  et obtient un shell root, puis tente d’abuser des capacités, volumes ou
  interfaces accessibles au conteneur pour atteindre l’hôte.

### 14. Mot de passe root défini sans besoin établi

- **Problème :** le Dockerfile crée un identifiant de connexion root alors que
  le service est censé démarrer l’application directement.
- **Danger :** cela crée un secret d’accès supplémentaire et peut faciliter
  les connexions interactives si SSH ou un autre mécanisme est ajouté par
  erreur.
- **Exploitation possible :** un attaquant qui découvre le secret et trouve
  une voie d’accès interactive compatible peut ouvrir une session root dans
  l’environnement concerné.

### 15. Aucun contrôle de provenance ou de signature

- **Problème :** le Dockerfile ne documente pas de vérification de provenance
  des images, paquets ou dépendances.
- **Danger :** il est difficile de prouver que les composants utilisés
  proviennent d’une source approuvée et n’ont pas été altérés.
- **Exploitation possible :** un attaquant qui compromet un miroir ou une
  dépendance de la chaîne d’approvisionnement fait intégrer un composant
  piégé, exécuté au build ou au démarrage.

### 16. Port déclaré sans règles réseau ni contrôle d’accès

- **Problème :** `EXPOSE 5000` documente le port, mais ne garantit pas à lui
  seul qu’il soit restreint; le Dockerfile ne décrit aucune règle réseau,
  authentification ou terminaison TLS.
- **Danger :** si l’orchestrateur publie ce port directement, l’application
  peut être accessible depuis des réseaux non prévus. `EXPOSE` n’est pas une
  protection.
- **Exploitation possible :** un attaquant atteint directement le service
  sur le port 5000 et exploite une route vulnérable ou une interface
  d’administration exposée.

### 17. Aucun contrôle d’état du service

- **Problème :** il n’y a pas de `HEALTHCHECK` pour vérifier l’état de
  l’application.
- **Danger :** un conteneur dégradé peut rester considéré comme disponible;
  l’orchestrateur peut continuer à lui envoyer du trafic.
- **Exploitation possible :** après avoir rendu le service partiellement
  indisponible ou manipulé son état, un attaquant profite de la supervision
  incomplète pour prolonger l’interruption ou masquer une compromission.

### 18. Aucun durcissement de l’environnement d’exécution

- **Problème :** le Dockerfile ne définit pas de système de fichiers en
  lecture seule, de limites de ressources, de capacités Linux réduites ou de
  politique de sécurité du runtime.
- **Danger :** le conteneur peut disposer de davantage de possibilités
  d’écriture, de ressources et de privilèges que nécessaire.
- **Exploitation possible :** après avoir compromis l’application, un
  attaquant modifie des fichiers persistants accessibles, épuise les
  ressources disponibles ou abuse de capacités laissées actives.

## Conclusion

Le Dockerfile divulgue des secrets, inclut des outils superflus et lance
l’application en root à partir d’une image mouvante. Il faut notamment
externaliser les secrets, épingler et vérifier les composants, réduire les
paquets, contrôler le contexte de build, et exécuter le service avec un
utilisateur non privilégié. La sécurité réseau et les limites de privilèges
doivent aussi être définies dans le déploiement, car `EXPOSE` ne les applique
pas.
