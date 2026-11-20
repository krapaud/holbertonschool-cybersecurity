# Rapport de durcissement du bastion NovaTech

**Système concerné :** VM Ubuntu `novatech-prod-02`  
**Date du rapport :** 20 novembre 2026  
**Classification :** Interne, sécurité informatique  
**Statut :** Préparé pour revue, validation sur la VM requise

## Executive Summary

Ce rapport décrit les mesures prévues pour réduire la surface d’attaque du
bastion NovaTech avant son éventuelle mise en DMZ. Le périmètre couvre les
paramètres réseau du noyau, les logiciels et outils installés, les privilèges,
les systèmes de fichiers temporaires, les services et l’accès SSH. Les scripts
du cursus automatisent une partie de ces actions et fournissent des contrôles
de vérification.

L’état initial décrit par le scénario présente plusieurs risques importants :
le transfert IP est actif, un binaire SUID personnalisé se trouve dans
`/usr/local/bin/backup`, le mode mono-utilisateur n’est pas protégé par mot de
passe et `/tmp` n’est pas monté avec `noexec`. Ces faiblesses peuvent faciliter
le pivot réseau, l’élévation de privilèges et l’exécution de fichiers déposés
dans un répertoire temporaire. Le plan de durcissement traite ces domaines et
prévoit de vérifier les services essentiels avant toute mise en production.

Les chiffres ci-dessous reprennent l’exemple de baseline fourni dans le sujet
du cursus. Ils servent de référence pédagogique et ne sont pas présentés comme
des résultats effectivement collectés sur la VM. La décision de mise en DMZ
reste suspendue à l’audit réel, à la résolution ou à l’acceptation documentée
des risques résiduels et à l’approbation du CISO.

## Baseline Assessment

### État initial avant durcissement

Le résultat de référence présenté dans l’exercice 0 est un score Lynis initial
de **62/100**, obtenu après **256 tests**, avec **18 avertissements** et
**45 suggestions**. Les constats initiaux relevés dans cet exemple sont :

- Le mode mono-utilisateur ne demande pas de mot de passe.
- Le binaire personnalisé `/usr/local/bin/backup` possède le bit SUID.
- Le transfert IP est activé sur le serveur.
- Le montage de `/tmp` ne comporte pas l’option `noexec`.

Ces constats indiquent des risques d’accès privilégié, de pivot réseau et
d’exécution de programmes depuis un répertoire temporaire. Ils motivent les
mesures réseau, privilèges et systèmes de fichiers décrites dans ce rapport.

Le résultat à retenir pour la VM est celui produit par `0-lynis_baseline.sh`
avant toute modification. Ce script archive l’audit dans
`/var/log/hardening/baseline-<date>.txt`. Remplacer les chiffres d’exemple
suivants par les données archivées avant de signer le rapport.

| Indicateur Lynis | Valeur de référence |
| --- | --- |
| Hardening Index | 62, exemple du sujet à confirmer |
| Tests effectués | 256, exemple du sujet à confirmer |
| Avertissements | 18, exemple du sujet à confirmer |
| Suggestions | 45, exemple du sujet à confirmer |
| Date de l’audit | À renseigner après exécution dans la VM |

## 3. Mesures de durcissement

Les éléments ci-dessous recensent les mesures implémentées dans les scripts
du parcours. Leur application effective doit être confirmée dans la VM.

### Réseau et noyau

- Désactivation du transfert IPv4 et IPv6, avec persistance dans sysctl.
- Blocage de l’acceptation des redirections ICMP et de leur émission IPv4.
- Activation du filtrage strict `rp_filter` contre les adresses source usurpées.
- Activation des SYN cookies pour mieux résister aux SYN floods.
- Désactivation des réponses aux pings broadcast et des routes source.
- Vérification des paramètres actifs et de leur persistance avec
  `8-verify_kernel.sh`.

Scripts concernés : `2-disable_forwarding.sh`, `3-block_redirects.sh`,
`4-rp_filter.sh`, `5-syn_cookies.sh`, `6-icmp_config.sh`,
`7-source_routing.sh` et `8-verify_kernel.sh`.

### Paquets et outils système

- Inventaire des outils de développement, de diagnostic réseau et d’accès
  distant pouvant être inutiles sur un serveur de production.
- Suppression des compilateurs ou restriction de leur accès lorsque leur
  suppression n’est pas adaptée.
- Restriction des outils réseau aux comptes autorisés.
- Inventaire des binaires système connus pour pouvoir être détournés, avec
  examen de leurs permissions.

Scripts concernés : `9-package_audit.sh`, `10-remove_compilers.sh`,
`11-restrict_nettools.sh` et `12-lolbins_audit.sh`.

### Privilèges et binaires SUID/SGID

- Recensement et classification des binaires SUID et SGID.
- Retrait du bit SUID uniquement pour les binaires jugés non essentiels,
  après examen des besoins opérationnels.
- Verrouillage du compte root prévu avec vérification préalable de sudo.

Scripts concernés : `13-suid_audit.sh`, `15-remove_suid.sh` et
`21-lock_root.sh`. Toute modification SUID doit être validée avec
l’administrateur système afin d’éviter une interruption de service.

### Systèmes de fichiers temporaires

- Configuration de `/tmp`, `/var/tmp` et `/dev/shm` avec les options
  `noexec`, `nosuid` et `nodev` lorsque la configuration du système le permet.
- Vérification des options de montage et tests de blocage de l’exécution.

Scripts concernés : `17-harden_tmp.sh`, `18-harden_other_tmp.sh` et
`19-verify_filesystem.sh`.

### Services et accès SSH

- Identification puis désactivation des services qui ne sont pas nécessaires
  au rôle de bastion. SSH et le serveur Web requis doivent rester disponibles.
- Configuration d’une bannière légale SSH et rechargement du service après
  validation de la configuration.

Scripts concernés : `20-minimize_services.sh` et `22-legal_banner.sh`.
Le verrouillage root est également documenté dans la section privilèges.

## 4. Évaluation finale

Après application des mesures, exécuter `23-final_audit.sh` dans la VM. Le
script compare Lynis à la baseline disponible et archive le résumé dans
`/var/log/hardening/final-<date>.txt`.

| Indicateur Lynis | Avant | Après | Écart |
| --- | --- | --- | --- |
| Hardening Index | À relever | À relever | À calculer |
| Tests effectués | À relever | À relever | À calculer |
| Avertissements | À relever | À relever | À calculer |
| Suggestions | À relever | À relever | À calculer |

**Référence à joindre :** chemin et date des rapports baseline et final dans
`/var/log/hardening/`.

## 5. Recommandations restantes

Avant toute approbation de mise en DMZ :

1. Exécuter les audits initial et final dans la VM, puis renseigner les
   tableaux avec les valeurs observées, sans reprendre les valeurs d’exemple
   du sujet.
2. Examiner chaque avertissement et suggestion Lynis restante et attribuer un
   responsable ainsi qu’une échéance.
3. Confirmer que les services nécessaires fonctionnent toujours, notamment
   le service Web et l’accès SSH d’administration.
4. Vérifier après redémarrage la persistance des réglages noyau et options de
   montage.
5. Conserver les sorties d’audit, les journaux de changement et les preuves
   de vérification pour la revue de conformité.
6. Faire approuver les risques résiduels et la mise en DMZ par le CISO.

## 6. Liste de validation et signatures

- [ ] Baseline Lynis exécutée sur `novatech-prod-02` et rapport archivé.
- [ ] Mesures réseau appliquées et vérifiées, y compris après redémarrage.
- [ ] Paquets, outils et services examinés avec les responsables concernés.
- [ ] Binaires SUID/SGID examinés et changements autorisés.
- [ ] Options `noexec`, `nosuid` et `nodev` vérifiées sur les répertoires ciblés.
- [ ] Accès SSH, bannière et méthode d’administration validés.
- [ ] Audit Lynis final exécuté et comparé à la baseline.
- [ ] Résultats et risques résiduels examinés par le CISO.
- [ ] Autorisation de mise en DMZ accordée.

| Rôle | Nom | Décision | Date | Signature |
| --- | --- | --- | --- | --- |
| Administrateur système | À renseigner | En attente | À renseigner | À renseigner |
| Responsable sécurité | À renseigner | En attente | À renseigner | À renseigner |
| CISO | À renseigner | En attente | À renseigner | À renseigner |
