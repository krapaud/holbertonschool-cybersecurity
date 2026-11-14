# Patch Management & Lifecycle

Ce dossier regroupe les exercices du projet Holberton consacré à la remise en état du gestionnaire APT, à la correction des vulnérabilités et à la mise en place d’une gestion durable des mises à jour.

## Environnement

Les scripts sont prévus pour Ubuntu et doivent être exécutés dans la VM de laboratoire `novatech-prod-01`. Les vérifications et changements effectués sur la VM doivent respecter les consignes du projet : sauvegarde avant toute modification, validation avant application, journalisation et possibilité de retour arrière.

## Tâche 0 : diagnostic APT et DPKG

```bash
chmod +x 0-diagnose_apt.sh
sudo ./0-diagnose_apt.sh
```

Le diagnostic ne supprime pas les fichiers de verrouillage et ne modifie pas la base des paquets. Il vérifie leur détenteur, les états DPKG, les opérations interrompues, les sources APT et la cohérence signalée par DPKG.

## Tâches 1 à 10 : remise en état et remédiation

Exécuter les scripts numérotés dans l’ordre dans la VM, en examinant leur sortie avant de passer à l’étape suivante. Les scripts qui modifient le système demandent les droits root et créent des sauvegardes avant leurs changements. La tâche 10 vérifie les éléments traités.

## Tâche 11 : comprendre APT

La réponse sur les sources, les suites Ubuntu et les priorités APT est dans [`11-understanding_apt.md`](11-understanding_apt.md).

## Tâches 12 à 24 : cycle de correctifs

Les scripts contrôlent la politique des paquets, configurent unattended-upgrades, limitent les mises à jour aux dépôts de sécurité, protègent certains services, programment une fenêtre et un redémarrage, consignent les opérations, simulent les correctifs, analysent les incidents, gèrent les retours arrière et les paquets retenus, puis sauvegardent la configuration.

Les tâches 21 à 23 peuvent modifier l’état des paquets. Vérifier leur simulation et leur cible avant de confirmer.

## Tâches 25 à 27 : documents

- [`25-patch_note.md`](25-patch_note.md) décrit la politique de gestion des correctifs.
- [`26-playbook.md`](26-playbook.md) décrit la réponse à un incident après mise à jour.
- [`27-remediation_report.md`](27-remediation_report.md) distingue le plan livré des remédiations effectivement vérifiées sur la VM.

## Vérifications locales

Les scripts peuvent être vérifiés sans toucher à la VM avec `bash -n *.sh` et `git diff --check`. Les scripts de remédiation, en revanche, doivent être exécutés uniquement dans la VM de laboratoire.

