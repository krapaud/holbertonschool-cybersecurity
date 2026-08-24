# Strategy Layer

## Introduction

Dans les modules précédents, l'objectif était de maîtriser le système Linux et les réseaux. Dans ce module, on change de niveau : il faut apprendre à analyser la logique métier et les décisions qui rendent une organisation vulnérable.

Une entreprise peut investir plusieurs millions dans ses outils de sécurité et rester vulnérable si ses processus, ses contrôles physiques ou ses règles d'accès comportent des failles.

> « Si vous pensez que la technologie peut résoudre vos problèmes de sécurité, alors vous ne comprenez ni les problèmes ni la technologie. »
> Bruce Schneier

## Contexte du projet

### Le client

`ApexFin Global` est une société de trading haute fréquence.

### La situation

L'entreprise a subi une attaque par rançongiciel malgré un budget annuel de 5 millions de dollars consacré à la cybersécurité. Elle utilise notamment un EDR avancé, des pare-feux nouvelle génération et une architecture Zero Trust.

### La mission

`DefendSec Consulting` doit réaliser une analyse des causes profondes, ou RCA, au niveau conceptuel. L'objectif n'est pas de réparer les serveurs, mais d'expliquer comment les contrôles ont échoué et quelles conséquences métier en résultent.

## Objectifs pédagogiques

À la fin du cours, il faut savoir expliquer :

- la relation entre actif, menace, vulnérabilité et risque ;
- l'impact d'un incident sur la confidentialité, l'intégrité et la disponibilité ;
- la différence entre authentification et autorisation ;
- le rôle de l'accounting dans la traçabilité et la non-répudiation ;
- le calcul de l'ALE pour comparer un risque au coût d'un contrôle de sécurité.

## Les notions fondamentales

### Actif

Un actif est une ressource ayant une valeur pour l'organisation. Il peut s'agir d'un serveur, d'une donnée, d'un compte, d'un service, d'un local ou d'un processus métier.

Pour l'identifier, demander :

1. Qu'est-ce qui doit être protégé ?
2. Quelle est sa valeur financière ou opérationnelle ?
3. Que se passerait-il s'il devenait indisponible, faux ou divulgué ?

### Menace

Une menace est un événement, une personne ou une situation capable de causer un dommage à un actif.

Exemples : incendie, fuite d'eau, vol, erreur humaine, divulgation d'un mot de passe, rançongiciel ou accès non autorisé.

### Vulnérabilité

Une vulnérabilité est une faiblesse exploitable par une menace.

Exemples : câble exposé à une fuite, mot de passe affiché publiquement, clé de coffre facilement accessible ou absence de contrôle d'accès.

### Risque

Le risque représente la possibilité qu'une menace exploite une vulnérabilité et provoque un impact.

Formule qualitative :

```text
Risque = Probabilité × Impact
```

Formulation complète :

```text
Menace + Vulnérabilité → Événement dommageable → Impact métier
```

L'analyse ne doit pas seulement nommer la faiblesse. Elle doit expliquer le scénario d'exploitation et ses conséquences.

## Triade CIA

La triade CIA décrit les trois propriétés principales de la sécurité de l'information.

| Propriété | Question | Exemple d'atteinte |
| --- | --- | --- |
| Confidentialité | Qui peut voir l'information ? | Un mot de passe exposé |
| Intégrité | L'information ou le système reste-t-il fiable et non modifié ? | Données de trading altérées |
| Disponibilité | Le service reste-t-il accessible au moment nécessaire ? | Serveur arrêté après une fuite d'eau |

Un même incident peut toucher plusieurs propriétés. Il faut identifier l'impact principal et justifier les impacts secondaires.

## AAA

AAA signifie Authentication, Authorization et Accounting.

### Authentication

L'authentification répond à la question : « Qui êtes-vous ? »

Exemples : mot de passe, clé, certificat, facteur biométrique ou code à usage unique.

### Authorization

L'autorisation répond à la question : « Qu'avez-vous le droit de faire ? »

Une personne peut être correctement authentifiée mais disposer de droits excessifs. L'authentification seule ne garantit donc pas qu'un accès est légitime.

### Accounting

L'accounting consiste à enregistrer qui a fait quoi, quand, depuis où et avec quel résultat.

Ces journaux permettent la détection, l'investigation, l'audit et la non-répudiation. Sans traces fiables, il devient difficile d'attribuer une action à une personne ou à un compte.

## Authentification, autorisation et non-répudiation

Ne pas confondre les questions suivantes :

```text
Authentification : Qui es-tu ?
Autorisation     : Que peux-tu faire ?
Accounting       : Qu'as-tu fait et quand ?
```

La non-répudiation dépend de preuves suffisamment fiables pour empêcher une personne de nier une action qu'elle a réellement effectuée. Les journaux doivent donc être protégés contre la modification et associés à une identité correctement contrôlée.

## Analyse quantitative du risque

### SLE

La `Single Loss Expectancy` représente la perte attendue pour un seul incident.

```text
SLE = Asset Value × Exposure Factor
```

L'`Exposure Factor` est la proportion de la valeur de l'actif perdue lors d'un incident.

### ARO

L'`Annualized Rate of Occurrence` représente le nombre estimé d'incidents par an.

### ALE

L'`Annualized Loss Expectancy` représente la perte annuelle attendue.

```text
ALE = SLE × ARO
```

L'ALE aide à comparer le coût annuel d'un contrôle avec la perte annuelle attendue. Ce calcul reste une estimation : il faut documenter les hypothèses et éviter de présenter un résultat incertain comme une valeur exacte.

## Méthode de Root Cause Analysis

Pour analyser un incident ou une observation :

1. Identifier l'actif concerné.
2. Identifier la menace crédible.
3. Identifier la vulnérabilité précise.
4. Décrire le scénario d'exploitation.
5. Classer les impacts dans la triade CIA.
6. Déterminer la rupture éventuelle dans la chaîne AAA.
7. Estimer la probabilité et l'impact.
8. Relier la conséquence technique à la conséquence métier.
9. Vérifier si le risque a été correctement évalué.

## Cadre d'analyse des observations physiques

Pour chaque observation, compléter ce tableau :

| Élément | Analyse à produire |
| --- | --- |
| Asset | Ressource ou valeur à protéger |
| Threat | Événement ou acteur dangereux |
| Vulnerability | Faiblesse exploitable observée |
| Scenario | Manière dont la menace exploite la faiblesse |
| CIA | Confidentialité, intégrité ou disponibilité affectée |
| AAA | Authentification, autorisation ou accounting concerné |
| Impact | Conséquence opérationnelle et financière |
| Risk | Probabilité, impact et justification |

### Exemple de raisonnement, sans solution d'exercice

Une installation physique défectueuse ne doit pas être décrite uniquement comme « dangereuse ». Il faut relier la condition observée à un événement, puis à un impact :

```text
Condition physique → Événement possible → Actif touché → Impact CIA → Perte métier
```

## Erreurs fréquentes

- Confondre une menace avec la faiblesse qui la rend possible.
- Mentionner uniquement un outil de sécurité sans analyser le processus métier.
- Dire qu'un mot de passe exposé est automatiquement une attaque sans décrire l'accès rendu possible.
- Classer tous les incidents uniquement dans la disponibilité.
- Oublier les contrôles physiques et humains.
- Donner une valeur ALE sans expliquer les hypothèses utilisées.
- Affirmer qu'une authentification réussie signifie que toutes les actions sont autorisées.

## Format conseillé pour les réponses

Une réponse professionnelle peut suivre ce modèle :

```text
Actif : ...
Menace : ...
Vulnérabilité : ...
Scénario : ...
Impact CIA : ...
AAA concerné : ...
Conséquence métier : ...
Évaluation du risque : ...
```

Les réponses doivent être concises, justifiées et techniquement précises. L'objectif est de démontrer le raisonnement, pas d'accumuler des mots-clés.

## Ressources du cours

Les ressources fournies dans l'énoncé portent notamment sur :

- la triade CIA et AAA ;
- l'équation du risque ;
- le Business Impact Analysis ;
- les bases de la sécurité de l'information selon NIST SP 800-12 ;
- l'authenticité et la non-répudiation ;
- la gestion des risques et le NIST CSF 2.0.

Les liens intranet associés restent dans l'énoncé original du projet.
