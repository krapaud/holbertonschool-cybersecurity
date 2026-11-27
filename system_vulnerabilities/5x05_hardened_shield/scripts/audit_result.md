# Audit de sécurité Hardened Shield

- Date : 2026-11-27 10:54:56 UTC
- Résultat général : **FAIL**
- Score global : **75%** (41/55)

## Scores par catégorie

- Durcissement du noyau: **45%** (10/22)
- Sécurité du système de fichiers: **100%** (7/7)
- Sécurité des identités: **100%** (14/14)
- Sécurité des services: **80%** (4/5)
- Sécurité du conteneur: **86%** (6/7)

## Détail des contrôles

### Durcissement du noyau: 45% (10/22)

- [FAIL] Routage IPv4 désactivé: 1
- [PASS] Redirections IPv4 désactivées: 0
- [FAIL] Redirections IPv4 par défaut désactivées: 1
- [FAIL] Envoi de redirections IPv4 désactivé: 1
- [FAIL] Envoi de redirections IPv4 par défaut désactivé: 1
- [FAIL] Filtrage de chemin inverse IPv4 activé: 0
- [FAIL] Filtrage de chemin inverse IPv4 par défaut activé: 0
- [PASS] Cookies TCP SYN activés: 1
- [PASS] Routage source IPv4 désactivé: 0
- [FAIL] Routage source IPv4 par défaut désactivé: 1
- [PASS] Diffusions ICMP ignorées: 1
- [FAIL] Paquets martiens journalisés: 0
- [FAIL] Paquets martiens par défaut journalisés: 0
- [FAIL] Redirections IPv6 désactivées: 1
- [FAIL] Redirections IPv6 par défaut désactivées: 1
- [PASS] Routage source IPv6 désactivé: 0
- [PASS] Routage source IPv6 par défaut désactivé: 0
- [PASS] Routage IPv6 désactivé: 0
- [PASS] Randomisation de l’espace mémoire activée: 2
- [FAIL] Accès aux pointeurs du noyau limité: 0
- [PASS] Accès aux journaux du noyau limité: 1
- [PASS] Dumps mémoire des fichiers SUID désactivés: 0

### Sécurité du système de fichiers: 100% (7/7)

- [PASS] Permissions sûres sur /tmp: 1777
- [PASS] Options noexec,nosuid,nodev sur /tmp: nodev,noexec,nosuid,rw
- [PASS] Permissions sûres sur /var/tmp: 1777
- [PASS] Options noexec,nosuid,nodev sur /var/tmp: nodev,noexec,nosuid,rw
- [PASS] Accès privé à /etc/shadow: 0600
- [PASS] Accès privé à /etc/gshadow: 0600
- [PASS] Inventaire SUID/SGID présent: /run/hardened-shield-suid-audit.txt

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

### Sécurité des services: 80% (4/5)

- [PASS] Nginx actif: processus présent
- [PASS] SSH actif: processus présent
- [FAIL] Fail2ban actif: processus absent
- [PASS] Contrôle HTTP /health: ok
- [PASS] Services inutiles arrêtés: aucun processus détecté

### Sécurité du conteneur: 86% (6/7)

- [PASS] Exécution dans un conteneur: marqueur Docker/OCI
- [PASS] Worker Nginx sans privilèges root: UID 999
- [PASS] Capacités limitées aux droits nécessaires: 00000000000404c1
- [PASS] Option no-new-privileges activée: 1
- [PASS] Filtre Seccomp activé: 2
- [FAIL] Système de fichiers racine en lecture seule: rw
- [PASS] Aucun secret dans le Dockerfile: Dockerfile

## Conclusion

Le résultat PASS demande la réussite de tous les contrôles. Les
capacités, montages et réglages dépendent des options Docker
utilisées au lancement,
pas uniquement du contenu de l’image.
