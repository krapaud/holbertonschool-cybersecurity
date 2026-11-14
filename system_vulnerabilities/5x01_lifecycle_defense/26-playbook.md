# Procédure de réponse à un incident après correctif

## Déclenchement

Ouvrir un incident si un service critique échoue après une mise à jour, si les contrôles de santé échouent, si les erreurs augmentent nettement ou si une dépendance empêche le démarrage. Noter l’heure, le serveur, le paquet et le symptôme observé.

## Cinq premières minutes

1. Alerter l’astreinte système et le responsable applicatif.
2. Confirmer l’impact utilisateur et déterminer si le service est totalement ou partiellement indisponible.
3. Éviter les nouvelles installations et préserver les journaux APT, DPKG, systemd et applicatifs.
4. Vérifier les opérations de paquet et identifier les versions récemment installées.
5. Décider avec le responsable d’incident si l’on restaure le service, isole l’hôte ou poursuit le diagnostic.

## Diagnostic

Comparer l’heure de panne avec `/var/log/apt/history.log` et `/var/log/dpkg.log`. Examiner `dpkg --audit`, `apt-get check`, `systemctl status nom.service`, `journalctl -u nom.service` et la configuration du service. Simuler toute résolution APT et examiner les suppressions proposées avant de l’appliquer. Ne pas supprimer un fichier de verrouillage tant qu’un processus APT ou DPKG l’utilise.

## Retour arrière

1. Utiliser le paquet précédent uniquement si cette version est disponible depuis une source fiable ou dans le cache local.
2. Consulter et valider la simulation `apt-get -s install paquet=version`.
3. Vérifier que le retour arrière ne supprime pas une dépendance critique.
4. Restaurer la configuration sauvegardée si elle a été modifiée avec le correctif.
5. Appliquer le retour arrière autorisé, puis contrôler la version, l’état DPKG et la santé du service.
6. Si une migration de données est irréversible, restaurer le snapshot ou la sauvegarde cohérente plutôt que de forcer une ancienne version.

## Communication et clôture

Informer les parties concernées de l’impact, des mesures temporaires et de l’heure de prochaine mise à jour. À la clôture, confirmer le rétablissement, conserver les preuves, documenter la cause, le paquet en cause, le temps d’interruption et les améliorations de test ou de déploiement.
