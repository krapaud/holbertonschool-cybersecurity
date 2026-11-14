# Rapport final de remédiation et de gestion des correctifs

**Client :** NovaTech

**Système concerné :** `novatech-prod`, Ubuntu 20.04 LTS en laboratoire

**Classification :** Confidentiel, diffusion limitée aux personnes autorisées

## Résumé exécutif (Executive Summary)

L’évaluation de NovaTech a relevé plusieurs faiblesses sur
`novatech-prod` :
droits sudo sans restriction pour le compte `auditor`, SSH autorisant
l’accès root par mot de passe, FTP anonyme, MySQL à l’écoute sur toutes
les interfaces, secrets dans le répertoire web et fichiers aux permissions
risquées. Le rapport précédent, `28-vulnerability_assessment_report.txt`,
détaille les preuves. Aucun CVE n’a été confirmé comme applicable aux
versions observées.

Le scénario de ce projet ajoute un incident opérationnel : Kevin a
interrompu une mise à niveau. APT/DPKG peut alors laisser des paquets
dépaquetés ou à moitié configurés, avec un risque d’indisponibilité
pour Apache et les applications qui en dépendent. Une réparation précipitée
peut aggraver l’incident ou masquer sa cause. Le risque global est
**élevé**, car la continuité du service est menacée.
Les contrôles d’accès restent faibles. Les pertes et la durée
d’indisponibilité restent à chiffrer faute de données métier.

Le dépôt fournit un parcours de diagnostic, de réparation, de validation
et de gestion durable des correctifs. Il prévoit des sauvegardes, une
simulation APT, des journaux, une fenêtre de maintenance, des règles
d’exclusion temporaires et un retour arrière. Ces scripts sont livrés.
Leur présence ne prouve pas qu’ils ont été exécutés
ni que la VM est corrigée. Les sorties d’exécution et les contrôles après
intervention doivent être conservés comme preuves.

Sous 48 heures, l’équipe doit confirmer l’état réel.
Elle doit aussi sécuriser les accès privilégiés. Sous sept jours, elle doit
rétablir APT/DPKG et Apache, puis restreindre SSH et MySQL. Sous 30 à
90 jours, NovaTech doit déployer le cycle de correctifs, suivre les
exceptions et tester la restauration.

## État initial (Initial State) et périmètre

Le scénario signale une mise à niveau APT interrompue, un paquet PHP à
moitié configuré et Apache arrêté. L’évaluation précédente a aussi
relevé les problèmes suivants :

- Le compte `auditor` peut obtenir les privilèges root sans mot de passe.
- SSH permet la connexion root et l’authentification par mot de passe.
- FTP accepte les connexions anonymes.
- MySQL écoute sur `0.0.0.0`.
- Des secrets sont présents dans `/var/www/html`.
- Des fichiers ont des permissions qui permettent des modifications
  non autorisées.

L’accès depuis Internet n’a pas été établi. Les constats doivent être
reconfirmés dans la VM avant d’être considérés comme l’état actuel.
Le périmètre couvre APT/DPKG, les dépôts, Apache, SSH, MySQL, FTP, les
permissions, les mises à jour automatiques, les redémarrages, les journaux
et les retours arrière.

## Actions de remédiation (Remediation Actions)

Les actions décrites ici sont implémentées dans le dépôt. Elles doivent
être exécutées et vérifiées sur la VM avant validation.

### Diagnostic et récupération

- `0-diagnose_apt.sh` vérifie les verrous, les états DPKG, les opérations
  interrompues et les sources sans modifier le système.
- `1-unlock_dpkg.sh`, `2-repair_packages.sh` et `3-fix_sources.sh`
  encadrent le déblocage, la configuration des paquets et la réparation
  des dépôts, avec sauvegardes et vérifications.
- Après intervention, vérifier `dpkg --audit`, `apt-get check` et
  l’exécution d’APT. Ne jamais retirer un verrou encore utilisé.

### Services et contrôles d’accès

- `4-restore_apache.sh` teste la configuration, redémarre Apache et
  vérifie que `http://127.0.0.1/` renvoie le code HTTP 200.
- `5-remove_vsftpd.sh` sauvegarde la configuration, arrête et purge FTP,
  puis vérifie que le port 21 n’écoute plus.
- `7-harden_ssh.sh` valide la configuration avant rechargement et désactive
  l’accès root, les mots de passe et X11. Vérifier une deuxième session
  SSH avant de fermer la session courante.
- `8-harden_mysql.sh` sauvegarde la configuration, limite l’écoute à
  `127.0.0.1`, désactive `local-infile` et vérifie l’accès local.
- Contrôler les états systemd, les ports en écoute et la réponse HTTP
  après chaque changement.

### Cycle de correctifs

- `6-security_updates.sh` applique les mises à jour de sécurité ciblées.
- `13-setup_unattended.sh` configure les mises à jour périodiques et
  active puis vérifie `apt-daily.timer` et `apt-daily-upgrade.timer`.
- `14-security_only.sh` limite les origines automatiques à la suite de
  sécurité Ubuntu.
- `15-blacklist_packages.sh` exclut temporairement Apache et MySQL des
  mises à jour automatiques non testées. Cette exclusion ne dispense pas
  de leur appliquer les correctifs après validation.
- `16-maintenance_window.sh` programme les tâches à 02:00 et 03:00 avec
  un délai aléatoire. `17-reboot_policy.sh` prévoit un redémarrage à 04:30
  après une mise à jour qui l’exige si aucun utilisateur n’est connecté.
- Vérifier les simulations, les origines autorisées, les timers et les
  journaux unattended-upgrades.

### Suivi, retour arrière et validation

- `18-notification_setup.sh` configure un journal dédié, sa rotation et
  les notifications d’erreur.
- `19-dry_run.sh` simule unattended-upgrades sans installer de paquets.
  `20-identify_bad_update.sh` rapproche les journaux APT/DPKG de l’heure
  de l’incident.
- `21-rollback_package.sh` vérifie la version disponible, sauvegarde
  l’inventaire et `/etc`, simule la rétrogradation, demande confirmation
  et contrôle la version installée.
- `22-hold_package.sh` et `23-manage_holds.sh` gèrent les paquets retenus.
- `24-backup_config.sh` crée une archive horodatée des configurations,
  vérifie l’archive et enregistre son empreinte SHA-256.
- `10-verify_remediation.sh` contrôle l’état final. Conserver sa sortie,
  les journaux, la simulation et les sauvegardes comme preuves.

Un retour arrière dépend de la disponibilité d’une ancienne version et ne
défait pas nécessairement une migration de données. Toute rétrogradation
doit être précédée d’une simulation et suivie d’un contrôle de santé.

## Gestion des correctifs (Patch Management Implementation)

Le cycle prévu est : inventorier les paquets, vérifier les sources et les
versions candidates, consulter les avis de sécurité, simuler les
changements, faire approuver une fenêtre, sauvegarder, appliquer des
correctifs ciblés, puis vérifier les services et archiver les preuves.
Les urgences suivent une approbation accélérée, avec tests et plan de
retour arrière. Toute exception doit avoir un responsable, une justification,
des mesures compensatoires et une date d’expiration.

## Résultats et preuves

Le résultat confirmé à ce stade est la présence des scripts et procédures
dans le dépôt. L’exécution dans la VM, le rétablissement d’Apache, la
réparation de DPKG et le durcissement des services ne sont pas déclarés
comme accomplis sans leurs sorties de commande. Après intervention,
joindre le diagnostic avant et après, la simulation APT, l’état des
services et timers, les ports ouverts, le résultat de
`10-verify_remediation.sh`, ainsi que l’archive et son empreinte.

## Feuille de route

### Immédiat à 48 heures

- Préserver les journaux et diagnostiquer APT/DPKG sans retirer de verrou
  actif.
- Révoquer le sudo sans restriction de `auditor`, corriger les permissions
  dangereuses et retirer les secrets du répertoire web.
- Désactiver FTP anonyme ou retirer le service s’il n’est pas requis.

### Sous 7 jours

- Réparer les paquets interrompus et rétablir Apache avec contrôle HTTP.
- Désactiver la connexion SSH directe de root et les mots de passe après
  validation d’un accès par clé.
- Restreindre MySQL au réseau requis et appliquer les correctifs validés.

### Sous 30 jours

- Activer les mises à jour de sécurité, les simulations et les journaux.
- Tester la fenêtre de maintenance et le retour arrière en préproduction.
- Attribuer un responsable et une date d’expiration à chaque exception.

### Sous 90 jours

- Revoir les exceptions et les paquets retenus.
- Tester la restauration complète et mesurer les délais de correction.
- Réévaluer les services exposés, les permissions et les comptes
  privilégiés.

## Limites

Ce document reprend les constats de l’évaluation précédente et les
procédures créées pour le scénario de cycle de vie. Il ne certifie pas
l’état actuel de la VM ni une remise en état en production. L’exposition
réseau, l’impact financier, la réussite des mises à jour et les preuves
après correction doivent être confirmés par l’équipe NovaTech.
