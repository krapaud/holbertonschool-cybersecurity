# Access Control Models

Ce cours explique comment contrôler précisément qui peut accéder à une ressource, et dans quelles conditions.

## Pourquoi le contrôle d'accès est important

Un système est vulnérable lorsqu'une personne peut accéder à une ressource qu'elle ne devrait pas utiliser. Le contrôle d'accès limite cet accès et réduit l'impact d'une erreur, d'un compte compromis ou d'une menace interne.

Le projet prend comme contexte `SecureHealth`, un réseau hospitalier qui doit protéger des données médicales soumises à HIPAA.

## Les modèles principaux

### DAC, Discretionary Access Control

Dans le DAC, le propriétaire d'une ressource peut généralement décider qui peut y accéder. Les permissions Linux classiques et les ACL sont des exemples de DAC.

Avantage : modèle simple et flexible.

Limite : un propriétaire ou un compte privilégié peut parfois donner trop de droits.

### RBAC, Role-Based Access Control

Dans le RBAC, les droits sont liés à un rôle, puis les utilisateurs reçoivent un ou plusieurs rôles.

Exemple : un médecin, un infirmier, un comptable et un administrateur système n'ont pas les mêmes besoins.

Deux principes importants :

- `Least Privilege` : donner uniquement les droits nécessaires au travail.
- `Separation of Duties` : séparer les responsabilités importantes entre plusieurs personnes.

### ABAC, Attribute-Based Access Control

Dans l'ABAC, une décision dépend de plusieurs attributs :

- l'identité ou le rôle de l'utilisateur ;
- la ressource demandée ;
- l'action demandée ;
- l'heure et le lieu ;
- l'appareil utilisé ;
- le niveau de confiance de la session.

L'ABAC permet de bloquer une action risquée même si l'utilisateur possède normalement le bon rôle.

### MAC, Mandatory Access Control

Dans le MAC, la politique est imposée par le système. L'utilisateur, y compris un administrateur, ne peut pas simplement modifier les règles pour obtenir tous les accès.

AppArmor et SELinux sont des technologies qui peuvent appliquer ce type de confinement.

## ACL Linux

Les permissions classiques Linux distinguent le propriétaire, le groupe et les autres utilisateurs. Une ACL permet d'ajouter une règle précise pour un utilisateur ou un groupe sans modifier le propriétaire ni les permissions standards.

Commandes utiles :

```bash
getfacl FILE
setfacl -m u:USER:r FILE
```

Dans un exercice ACL, vérifier que :

1. le chemin est bien reçu en argument ;
2. l'utilisateur ciblé reçoit uniquement le droit demandé ;
3. le propriétaire, le groupe et les permissions classiques restent inchangés ;
4. le script est exécutable et possède une nouvelle ligne finale.

## AppArmor et confinement

AppArmor associe une politique à un programme. Cette politique décrit les fichiers, capacités et actions autorisés pour ce programme.

Le confinement réduit le rayon d'action d'une application compromise. Il peut empêcher une application web de lire des fichiers sensibles, même si l'application possède un bug exploitable.

SELinux et AppArmor poursuivent un objectif similaire, mais leur fonctionnement et leur manière de définir les politiques sont différents. Il faut retenir ici que le MAC ajoute une couche contrôlée par le système, au-dessus des permissions classiques.

## Defense in Depth

La défense en profondeur consiste à empiler plusieurs protections indépendantes :

```text
Permissions Linux → ACL → RBAC/ABAC → AppArmor ou SELinux → Journalisation
```

Une couche ne remplace pas les autres. Si une couche échoue, les suivantes doivent encore limiter l'accès ou permettre de détecter l'incident.

## Méthode pour une règle ABAC

Pour transformer un scénario en règle ABAC, repérer les éléments suivants :

```text
Sujet     : qui fait l'action ?
Action    : que veut-il faire ?
Ressource : sur quelle donnée ?
Contexte  : dans quelles conditions ?
Décision  : ALLOW ou DENY ?
```

Pour la tâche « The Context Twist », le raisonnement consiste à combiner quatre faits du scénario : le rôle de la personne, le type d'action, la ressource ciblée et le contexte temporel ou matériel. La règle doit refuser uniquement le comportement dangereux tout en laissant les médecins travailler dans les situations normales.

Ne pas confondre RBAC et ABAC : RBAC répond surtout à « quel rôle possède cet utilisateur ? », alors qu'ABAC ajoute « dans quelles conditions cette action est-elle demandée ? ».

## Méthode de vérification

Pour vérifier une politique d'accès, tester au minimum :

- un utilisateur autorisé dans un contexte normal ;
- le même utilisateur dans un contexte risqué ;
- un utilisateur d'un autre rôle ;
- une autre ressource ;
- une action différente ;
- une application compromise essayant de sortir de son périmètre.

Une bonne politique applique le refus par défaut, documente chaque exception et laisse une trace de chaque décision importante.

## Ressources utiles

- `man chmod`
- `man chown`
- `man setfacl`
- `man getfacl`
- `man apparmor.d`
- `man aa-status`
- `man aa-enforce`
- `man aa-complain`
- `man apparmor_parser`
