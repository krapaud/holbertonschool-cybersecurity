# Linux Security — Sommaire des modules

Ce dossier regroupe tous les modules de sécurité Linux du parcours Holberton. L'objectif : maîtriser la sécurisation d'un système Linux de fond en comble — des permissions de fichiers jusqu'à l'automatisation d'un agent de surveillance.

---

## Modules

### [1x00 — Linux Fundamentals](1x00_linux_fundamentals/README.md)

Les fondations indispensables avant de toucher à la sécurité.

- Transfert de fichiers avec `scp` et exécution distante via `ssh`
- Recherche avancée avec `find` (critères multiples, redirection de stderr)
- Extraction de données avec `grep` récursif
- Pipelines Unix : `ls | awk | sort | uniq | head`
- Chasse aux binaires SUID (`find -perm -4000`)
- Attributs étendus : `chattr +i` (immutable), `lsattr`
- Répertoires partagés : SGID + Sticky Bit
- Délégation fine avec `sudo` et wrappers
- Politique de logs avec `logrotate`

---

### [1x01 — Shell Ops](1x01_shell_ops/README.md)

Opérations shell avancées pour automatiser efficacement.

- Redirection globale avec `exec >> fichier 2>&1`
- Substitution de processus `<(commande)` pour éviter les fichiers temporaires
- Traitement en masse avec `find` + `xargs`
- Anonymisation de logs avec `sed` et expressions régulières (IPv4)
- Filtrage conditionnel avec `awk` (colonnes, conditions, NR)
- Verrouillage de comptes en masse (`usermod -L`)
- Attente de service avec boucle `until` + `nc -z`
- Rotation de logs : `gzip`, `mv`, `stat -c%s`

---

### [1x02 — Identity Management](1x02_identity_management/README.md)

Gestion des identités et des droits sur un système Linux.

- Détection des comptes root cachés (UID=0 ≠ root dans `/etc/passwd`)
- Audit des comptes de service avec shell interactif
- Groupes à risque : `docker`, `disk`, `shadow`, `sudo`
- Durcissement SSH : `PermitRootLogin no`, `PasswordAuthentication no`
- Politique de mots de passe avec PAM (`pam_pwquality`)
- Audit des algorithmes de hachage dans `/etc/shadow` (MD5 = dangereux)
- Création sécurisée de comptes avec clé SSH dès l'onboarding
- Configuration granulaire de `sudo` (commandes précises, sans `ALL`)

---

### [1x03 — System Visibility](1x03_system_visibility/README.md)

Surveiller ce qui se passe sur un système en temps réel.

- `ps` : lister les processus, trier par CPU, filtrer par état
- `/proc/<PID>/environ` : lire les variables d'environnement d'un processus
- Processus zombies : détection et signification
- Hiérarchie des processus (PPID) — détecter les shells suspects
- Signaux : SIGTERM (15), SIGKILL (9), SIGSTOP, SIGCONT
- Ports en écoute : `ss -lnt4` et extraction des numéros de ports
- Identifier le programme derrière un port : `lsof -iTCP`
- Analyse de logs : filtrer par plage horaire avec `awk`
- Segfaults dans les logs kernel — indicateur d'exploitation

---

### [1x04 — Security Automation](1x04_security_automation/README.md)

Construire un agent de sécurité autonome avec systemd.

- Sentinel : agent de surveillance modulaire (services, intégrité, ports)
- `pgrep -f` pour surveiller les processus par nom
- Vérification d'intégrité par hash MD5 avec copie de référence (`.gold`)
- `ss -K` pour couper des connexions non autorisées
- Logs structurés au format JSON avec horodatage ISO 8601
- `systemd` : `.service` (oneshot) et `.timer` (remplacement de cron)
- `systemctl enable/start/status`, `journalctl -u`
- Principes : idempotence, validation avant action, moindre privilège

---

### [1x05 — Hardening](1x05_hardening/README.md)

Framework de durcissement automatisé conforme STIG-2024.

- SSH : désactivation mot de passe, interdiction root, validation `sshd -t`
- Réseau : politique deny-by-default, durcissement `sysctl` (ip_forward, icmp)
- Identité : PAM (`pam_pwquality`, `pam_faillock`), `/etc/login.defs`
- Système : mise à jour paquets, suppression outils dangereux (telnet, netcat)
- Installation `auditd` et `fail2ban`
- Rapport d'audit automatique `PASS`/`FAIL` à chaque exécution
