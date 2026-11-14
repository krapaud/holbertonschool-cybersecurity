# Rapport de remédiation et de gestion des correctifs

## Résumé

Le projet traite un serveur Ubuntu de production simulé dont la gestion des paquets est dégradée après une mise à niveau interrompue. Le plan couvre la remise en état d’APT et DPKG, le rétablissement des services, la réduction de l’exposition et l’installation d’un processus durable de correctifs.

Les scripts de ce dossier automatisent les contrôles et remédiations prévus. Ils sauvegardent les configurations avant modification, valident les changements lorsque possible, limitent les opérations APT aux paquets ciblés et consignent les actions. Le contenu préparé dans le dépôt ne prouve pas à lui seul que ces changements ont été appliqués à la VM.

## État initial et périmètre

Le scénario du cursus signale une opération APT interrompue, un paquet PHP à moitié configuré, Apache arrêté, un service FTP à supprimer, des réglages SSH et MySQL trop permissifs et des permissions à risque. Les éléments exacts de la VM doivent être confirmés par les tâches 0 et 10. Le périmètre est la VM Ubuntu de laboratoire et ses services Apache, SSH, MySQL et FTP.

## Actions prévues

1. Diagnostiquer les verrous, états DPKG, journaux et sources sans supprimer de verrou actif.
2. Débloquer APT après vérification de l’absence de processus, terminer les configurations interrompues et réparer les dépendances.
3. Tester les sources avant de désactiver une entrée invalide, avec sauvegarde préalable.
4. Restaurer Apache, supprimer vsftpd, appliquer les correctifs de sécurité ciblés, renforcer SSH et MySQL, puis corriger les permissions.
5. Exécuter le script de vérification et conserver les sorties de preuve.

## Gestion durable

Le projet ajoute des contrôles de politique APT, des mises à jour automatiques limitées aux origines de sécurité, des exclusions pour Apache et MySQL avant validation, une fenêtre de maintenance, une politique de redémarrage, des journaux, une simulation, des procédures de retour arrière et des sauvegardes de configuration.

## Résultats et limites

Les scripts et documents sont préparés dans le dépôt. L’exécution sur la VM et le résultat du checker de la plateforme restent à confirmer. Un retour arrière de paquet dépend de la disponibilité de l’ancienne version et ne défait pas nécessairement une migration de base de données. Les changements MySQL et SSH exigent un contrôle d’accès et de service après application.

## Prochaines étapes

- Immédiat : lancer le diagnostic, sécuriser l’accès à la VM et traiter tout correctif critique confirmé.
- Sous 7 jours : valider les mises à jour urgentes, les paramètres SSH/MySQL et les services exposés.
- Sous 30 jours : déployer les politiques APT, la fenêtre de maintenance et les tests de préproduction.
- Sous 90 jours : vérifier les exceptions, les journaux, la conformité et les procédures de restauration.

## Annexes et preuves

Les scripts numérotés 0 à 24 constituent les procédures. Les sorties des tâches 0, 10, 19 et les journaux APT/DPKG doivent être joints après exécution dans la VM. Aucune preuve d’exploitation ou de changement en production n’est affirmée par ce rapport en l’absence de ces sorties.
