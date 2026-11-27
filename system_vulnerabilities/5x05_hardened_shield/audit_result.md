# Hardened Shield: rapport d'audit

- Date: 2026-11-27 09:23:06 UTC
- Résultat global: **FAIL**
- Score: **42%** (16/38)

## Kernel hardening: 67% (4/6)

| Contrôle                      | Résultat | Détail |
| ----------------------------- | -------- | ------ |
| Redirections IPv4 désactivées | PASS     | 0      |
| Filtrage de route IPv4 activé | FAIL     | 0      |
| SYN cookies activés           | PASS     | 1      |
| Randomisation mémoire activée | PASS     | 2      |
| Pointeurs noyau masqués       | FAIL     | 0      |
| Dumps SUID désactivés         | PASS     | 0      |

## Filesystem security: 29% (2/7)

| Contrôle                                 | Résultat | Détail     |
| ---------------------------------------- | -------- | ---------- |
| Permissions sûres sur /tmp               | PASS     | 1777       |
| Options noexec,nosuid,nodev sur /tmp     | FAIL     | rw         |
| Permissions sûres sur /var/tmp           | PASS     | 1777       |
| Options noexec,nosuid,nodev sur /var/tmp | FAIL     | rw         |
| Accès privé à /etc/shadow                | FAIL     | 0640       |
| Accès privé à /etc/gshadow               | FAIL     | 0640       |
| Inventaire SUID/SGID présent             | FAIL     | non généré |

## Identity security: 50% (7/14)

| Contrôle                         | Résultat | Détail               |
| -------------------------------- | -------- | -------------------- |
| pam_pwquality actif              | PASS     | common-password      |
| Politique mot de passe minlen    | FAIL     | absent               |
| Politique mot de passe dcredit   | FAIL     | absent               |
| Politique mot de passe ucredit   | FAIL     | absent               |
| Politique mot de passe lcredit   | FAIL     | absent               |
| Politique mot de passe ocredit   | FAIL     | absent               |
| Historique de cinq mots de passe | FAIL     | PAM                  |
| Verrouillage après cinq échecs   | FAIL     | faillock.conf        |
| SSH PermitRootLogin              | PASS     | no                   |
| SSH PasswordAuthentication       | PASS     | no                   |
| SSH PubkeyAuthentication         | PASS     | yes                  |
| SSH AllowUsers                   | PASS     | shieldadmin          |
| Syntaxe de sshd_config           | PASS     | configuration valide |
| Mot de passe root verrouillé     | PASS     | passwd -S            |

## Service security: 20% (1/5)

| Contrôle                  | Résultat | Détail                  |
| ------------------------- | -------- | ----------------------- |
| Nginx actif               | FAIL     | processus absent        |
| SSH actif                 | FAIL     | processus absent        |
| Fail2ban actif            | FAIL     | processus absent        |
| Contrôle HTTP /health     | FAIL     | endpoint non joignable  |
| Services inutiles arrêtés | PASS     | aucun processus détecté |

## Container security: 33% (2/6)

| Contrôle                           | Résultat | Détail              |
| ---------------------------------- | -------- | ------------------- |
| Exécution dans un conteneur        | PASS     | marqueur Docker/OCI |
| Worker Nginx non-root              | FAIL     | aucun worker actif  |
| Aucune capability effective        | FAIL     | 00000000a80425fb    |
| no-new-privileges actif            | FAIL     | 0                   |
| Rootfs en lecture seule            | FAIL     | rw                  |
| Aucun secret intégré au Dockerfile | PASS     | Dockerfile          |

## Conclusion

Le statut PASS exige que tous les contrôles réussissent. Les contrôles
de capabilities, de montage et d'exécution reflètent les options Docker
réellement utilisées au lancement, et non seulement le contenu de l'image.
