# Hardened Shield: rapport d'audit

- Date: 2026-11-27 09:32:49 UTC
- Résultat global: **FAIL**
- Score: **42%** (23/55)

## Scores par catégorie

- Kernel hardening: **45%** (10/22)
- Filesystem security: **29%** (2/7)
- Identity security: **50%** (7/14)
- Service security: **20%** (1/5)
- Container security: **43%** (3/7)

## Détails des contrôles

### Kernel hardening: 45% (10/22)

- [FAIL] Routage IPv4 désactivé: 1
- [PASS] Redirections IPv4 désactivées: 0
- [FAIL] Redirections IPv4 par défaut désactivées: 1
- [FAIL] Envoi de redirections IPv4 désactivé: 1
- [FAIL] Envoi de redirections IPv4 par défaut désactivé: 1
- [FAIL] Filtrage de route IPv4 activé: 0
- [FAIL] Filtrage de route IPv4 par défaut activé: 0
- [PASS] SYN cookies activés: 1
- [PASS] Source routing IPv4 désactivé: 0
- [FAIL] Source routing IPv4 par défaut désactivé: 1
- [PASS] ICMP broadcast ignoré: 1
- [FAIL] Paquets martiens journalisés: 0
- [FAIL] Paquets martiens par défaut journalisés: 0
- [FAIL] Redirections IPv6 désactivées: 1
- [FAIL] Redirections IPv6 par défaut désactivées: 1
- [PASS] Source routing IPv6 désactivé: 0
- [PASS] Source routing IPv6 par défaut désactivé: 0
- [PASS] Routage IPv6 désactivé: 0
- [PASS] Randomisation mémoire activée: 2
- [FAIL] Pointeurs noyau masqués: 0
- [PASS] Accès aux logs noyau restreint: 1
- [PASS] Dumps SUID désactivés: 0

### Filesystem security: 29% (2/7)

- [PASS] Permissions sûres sur /tmp: 1777
- [FAIL] Options noexec,nosuid,nodev sur /tmp: rw
- [PASS] Permissions sûres sur /var/tmp: 1777
- [FAIL] Options noexec,nosuid,nodev sur /var/tmp: rw
- [FAIL] Accès privé à /etc/shadow: 0640
- [FAIL] Accès privé à /etc/gshadow: 0640
- [FAIL] Inventaire SUID/SGID présent: non généré

### Identity security: 50% (7/14)

- [PASS] pam_pwquality actif: common-password
- [FAIL] Politique mot de passe minlen: absent
- [FAIL] Politique mot de passe dcredit: absent
- [FAIL] Politique mot de passe ucredit: absent
- [FAIL] Politique mot de passe lcredit: absent
- [FAIL] Politique mot de passe ocredit: absent
- [FAIL] Historique de cinq mots de passe: PAM
- [FAIL] Verrouillage après cinq échecs: faillock.conf
- [PASS] SSH PermitRootLogin: no
- [PASS] SSH PasswordAuthentication: no
- [PASS] SSH PubkeyAuthentication: yes
- [PASS] SSH AllowUsers: shieldadmin
- [PASS] Syntaxe de sshd_config: configuration valide
- [PASS] Mot de passe root verrouillé: passwd -S

### Service security: 20% (1/5)

- [FAIL] Nginx actif: processus absent
- [FAIL] SSH actif: processus absent
- [FAIL] Fail2ban actif: processus absent
- [FAIL] Contrôle HTTP /health: endpoint non joignable
- [PASS] Services inutiles arrêtés: aucun processus détecté

### Container security: 43% (3/7)

- [PASS] Exécution dans un conteneur: marqueur Docker/OCI
- [FAIL] Worker Nginx non-root: aucun worker actif
- [FAIL] Aucune capability effective: 00000000a80425fb
- [FAIL] no-new-privileges actif: 0
- [PASS] Filtre Seccomp actif: 2
- [FAIL] Rootfs en lecture seule: rw
- [PASS] Aucun secret intégré au Dockerfile: Dockerfile

## Conclusion

Le statut PASS exige que tous les contrôles réussissent. Les contrôles
de capabilities, de montage et d'exécution reflètent les options Docker
réellement utilisées au lancement, et non seulement le contenu de l'image.
