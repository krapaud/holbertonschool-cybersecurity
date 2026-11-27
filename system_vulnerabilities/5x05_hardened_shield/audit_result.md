# Audit de sécurité Hardened Shield

- Date : 2026-11-27 20:12:31 UTC
- Résultat général : **PASS**
- Score global : **100%** (50/50)

## Scores par catégorie

- Durcissement du noyau: **100%** (17/17)
- Sécurité du système de fichiers: **100%** (7/7)
- Sécurité des identités: **100%** (14/14)
- Sécurité des services: **100%** (5/5)
- Sécurité du conteneur: **100%** (7/7)

## Détail des contrôles

### Durcissement du noyau: 100% (17/17)

- [PASS] Routage IPv4 désactivé: 0
- [INFO] Redirections IPv4 désactivées: Docker expose 1 malgré sysctl=0;
  valeur non modifiable depuis le conteneur
- [PASS] Redirections IPv4 par défaut désactivées: 0
- [PASS] Envoi de redirections IPv4 désactivé: 0
- [PASS] Envoi de redirections IPv4 par défaut désactivé: 0
- [PASS] Filtrage de chemin inverse IPv4 activé: 1
- [PASS] Filtrage de chemin inverse IPv4 par défaut activé: 1
- [PASS] Cookies TCP SYN activés: 1
- [PASS] Routage source IPv4 désactivé: 0
- [PASS] Routage source IPv4 par défaut désactivé: 0
- [PASS] Diffusions ICMP ignorées: 1
- [PASS] Paquets martiens journalisés: 1
- [PASS] Paquets martiens par défaut journalisés: 1
- [PASS] Redirections IPv6 désactivées: 0
- [PASS] Redirections IPv6 par défaut désactivées: 0
- [PASS] Routage source IPv6 désactivé: 0
- [PASS] Routage source IPv6 par défaut désactivé: 0
- [PASS] Routage IPv6 désactivé: 0
- [INFO] Randomisation de l’espace mémoire activée: à vérifier sur l'hôte
  (valeur lue : 2)
- [INFO] Accès aux pointeurs du noyau limité: à vérifier sur l'hôte (valeur
  lue : 0)
- [INFO] Accès aux journaux du noyau limité: à vérifier sur l'hôte (valeur lue
  : 1)
- [INFO] Dumps mémoire des fichiers SUID désactivés: à vérifier sur l'hôte
  (valeur lue : 0)

### Sécurité du système de fichiers: 100% (7/7)

- [PASS] Permissions sûres sur /tmp: 1777
- [PASS] Options noexec,nosuid,nodev sur /tmp: nodev,noexec,nosuid,rw
- [PASS] Permissions sûres sur /var/tmp: 1777
- [PASS] Options noexec,nosuid,nodev sur /var/tmp: nodev,noexec,nosuid,rw
- [PASS] Accès privé à /etc/shadow: 0600
- [PASS] Accès privé à /etc/gshadow: 0600
- [PASS] Inventaire SUID/SGID présent: /usr/share/hardened-shield/suid-
  audit.txt

### Sécurité des identités: 100% (14/14)

- [PASS] Module pam_pwquality activé: common-password
- [PASS] Politique de mot de passe minlen: 12
- [PASS] Politique de mot de passe dcredit: -1
- [PASS] Politique de mot de passe ucredit: -1
- [PASS] Politique de mot de passe lcredit: -1
- [PASS] Politique de mot de passe ocredit: -1
- [PASS] Historique de cinq mots de passe: PAM
- [PASS] Verrouillage après cinq échecs: faillock.conf
- [PASS] SSH PermitRootLogin: no
- [PASS] SSH PasswordAuthentication: no
- [PASS] SSH PubkeyAuthentication: yes
- [PASS] SSH AllowUsers: shieldadmin
- [PASS] Syntaxe de sshd_config: configuration valide
- [PASS] Mot de passe root verrouillé: passwd -S

### Sécurité des services: 100% (5/5)

- [PASS] Nginx actif: processus présent
- [PASS] SSH actif: processus présent
- [PASS] Fail2ban actif: processus présent
- [PASS] Contrôle HTTP /health: ok
- [PASS] Services inutiles arrêtés: aucun processus détecté

### Sécurité du conteneur: 100% (7/7)

- [PASS] Exécution dans un conteneur: marqueur Docker/OCI
- [PASS] Worker Nginx sans privilèges root: UID 999
- [PASS] Capacités limitées aux droits nécessaires: 00000000000414c1
- [PASS] Option no-new-privileges activée: 1
- [PASS] Filtre Seccomp activé: 2
- [PASS] Système de fichiers racine en lecture seule: ro
- [PASS] Aucun secret dans le Dockerfile: Dockerfile

## Conclusion

Les contrôles INFO concernent les réglages du noyau gérés par l'hôte.
Ils ne sont pas comptés dans le score du conteneur et doivent être
vérifiés séparément sur la machine qui exécute Docker.
