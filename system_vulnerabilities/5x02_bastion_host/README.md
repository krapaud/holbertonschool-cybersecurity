# The Bastion Host

Ce dossier regroupe les exercices Holberton consacrés au durcissement d’un
serveur Ubuntu exposé sur Internet. L’objectif est de réduire sa surface
d’attaque tout en gardant Apache fonctionnel et l’accès SSH disponible.

## Environnement

Les exercices sont prévus pour la VM Multipass `novatech-prod-02`, avec le
compte de laboratoire `auditor`. Les changements doivent être persistants,
documentés et vérifiés après application. Tester les commandes et services
dans la VM avant de considérer une mesure comme terminée.

## Parcours

Le cursus couvre l’audit initial avec Lynis et le durcissement réseau du
noyau,
la réduction des logiciels installés, l’audit des binaires SUID/SGID, la
sécurisation des systèmes de fichiers temporaires et la conformité CIS. Le
rapport final doit expliquer les mesures appliquées et les décisions prises.

## Vérifications

La tâche 0 lance l’audit Lynis dans la VM et archive un résumé dans
`/var/log/hardening/`. Elle nécessite les droits root et ne doit pas être
exécutée sur la machine hôte.

Les scripts Bash doivent commencer par `#!/bin/bash`, être exécutables et se
terminer par une nouvelle ligne. Vérifier leur syntaxe avec
`bash -n nom_du_script.sh`. Les vérifications qui touchent au système doivent
être réalisées uniquement dans la VM de laboratoire.
