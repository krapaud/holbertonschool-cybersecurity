# Politique de gestion des correctifs

## Objectif et périmètre

Cette politique maintient les serveurs NovaTech à jour sans interrompre les services métier. Elle couvre les systèmes Ubuntu, leurs paquets, les dépôts APT, les mises à jour automatiques, les redémarrages et les retours arrière.

## Responsabilités

- L’équipe système maintient l’inventaire, les dépôts et les sauvegardes.
- L’équipe sécurité qualifie les avis, les CVE, l’exposition et les mesures compensatoires.
- Le responsable applicatif valide les changements affectant ses services.
- Le responsable de changement approuve la fenêtre, le plan de test et le retour arrière.

## Priorités et délais

- Critique ou exploitation active : évaluation immédiate, mesure de réduction du risque et correctif ciblé sous 24 à 48 heures.
- Élevé : correctif sous 7 jours.
- Moyen : correctif sous 30 jours.
- Faible : correctif sous 90 jours ou lors du cycle planifié.

La priorité tient compte de l’exposition, de la disponibilité d’un exploit, de l’impact métier, des dépendances et du score CVSS. Le score CVSS seul ne décide pas du calendrier.

## Cycle standard

1. Inventorier les paquets et vérifier l’origine et la version candidate avec `apt-cache policy`.
2. Consulter les avis de sécurité et déterminer les systèmes touchés.
3. Simuler les changements, vérifier les suppressions et dépendances, puis tester en préproduction.
4. Sauvegarder les configurations et données, consigner l’approbation et annoncer la fenêtre.
5. Installer les correctifs ciblés, vérifier les services et surveiller les journaux.
6. Archiver les versions, résultats, exceptions et preuves de validation.

## Services protégés et exceptions

Apache et MySQL sont exclus des mises à jour automatiques non testées. Cette exclusion ne constitue pas une exemption de correctif. Une exception doit nommer le propriétaire, le risque, les contrôles compensatoires, une date d’expiration et le plan de correction. Les correctifs urgents suivent une approbation accélérée avec tests et sauvegarde.

## Fenêtre et redémarrages

Les opérations planifiées ont lieu pendant une fenêtre annoncée. Les mises à jour du noyau nécessitent une validation du redémarrage, la conservation d’un noyau fonctionnel et un contrôle de santé applicatif après redémarrage. Aucun serveur ne redémarre automatiquement si des utilisateurs sont connectés.

## Suivi et conformité

Les actions sont horodatées dans le journal de gestion des correctifs. Les responsables vérifient chaque mois les paquets en attente, les paquets retenus, les exceptions expirées et les écarts de conformité.
