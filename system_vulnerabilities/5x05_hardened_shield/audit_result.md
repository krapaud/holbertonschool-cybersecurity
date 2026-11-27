# Hardened Shield: rapport d'audit

- Date: 2026-11-27 09:25:26 UTC
- Résultat global: **FAIL**
- Score: **42%** (16/38)

## Scores par catégorie

- Kernel hardening: **67%** (4/6)
- Filesystem security: **29%** (2/7)
- Identity security: **50%** (7/14)
- Service security: **20%** (1/5)
- Container security: **33%** (2/6)

## Détails des contrôles

### Kernel hardening: 67% (4/6)

- [PASS] Redirections IPv4 désactivées: 0
- [FAIL] Filtrage de route IPv4 activé: 0
- [PASS] SYN cookies activés: 1
- [PASS] Randomisation mémoire activée: 2
- [FAIL] Pointeurs noyau masqués: 0
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

### Container security: 33% (2/6)

- [PASS] Exécution dans un conteneur: marqueur Docker/OCI
- [FAIL] Worker Nginx non-root: aucun worker actif
- [FAIL] Aucune capability effective: 00000000a80425fb
- [FAIL] no-new-privileges actif: 0
- [FAIL] Rootfs en lecture seule: rw
- [PASS] Aucun secret intégré au Dockerfile: Dockerfile

## Conclusion

Le statut PASS exige que tous les contrôles réussissent. Les contrôles
de capabilities, de montage et d'exécution reflètent les options Docker
réellement utilisées au lancement, et non seulement le contenu de l'image.
