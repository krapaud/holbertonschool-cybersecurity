# Hardening — Mini-cours

> **Dépôt :** holbertonschool-cybersecurity
> **Répertoire :** `linux_security/1x05_hardening`

---

## Vue d'ensemble — Framework de durcissement modulaire

Ce module implémente un framework de durcissement Linux automatisé, conforme aux politiques STIG-2024. L'objectif est de passer d'un système "par défaut" à un système "durci" en appliquant une série de règles reproductibles et auditables.

### Architecture

```text
hardening/
├── harden.sh           # Point d'entrée — orchestre l'exécution des modules
├── config/
│   └── harden.cfg      # Variables de configuration centralisées
├── lib/
│   ├── ssh.sh          # Règles S-01, S-02 — Durcissement SSH
│   ├── network.sh      # Règles N-01, N-02, N-03 — Durcissement réseau
│   ├── identity.sh     # Règles I-01 à I-04 — Comptes et mots de passe
│   └── system.sh       # Règles H-01 à H-03 — Paquets système
└── audit_report.txt    # Rapport de conformité généré à chaque exécution
```

Le script utilise un statut global `STATUS` initialisé à `PASS`. N'importe quel module peut le passer à `FAIL` en cas d'erreur, ce qui garantit un rapport de conformité final fiable.

---

## Règles SSH — `lib/ssh.sh`

### S-01 : Authentification par clé publique uniquement

#### Pourquoi désactiver l'authentification par mot de passe SSH

L'authentification par mot de passe expose le service SSH aux attaques par force brute. Un attaquant peut tester des millions de combinaisons automatiquement. L'authentification par clé publique est asymétrique : la clé privée ne quitte jamais la machine cliente et aucun secret ne transite sur le réseau.

```bash
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
```

| Directive | Valeur | Effet |
| --- | --- | --- |
| `PasswordAuthentication` | `no` | Bloque toute connexion par mot de passe |
| `PubkeyAuthentication` | `yes` | Autorise uniquement les clés cryptographiques |

Le pattern `^#\?` permet de cibler aussi bien les lignes commentées (`#PasswordAuthentication`) que les lignes actives.

### S-02 : Interdire la connexion root directe

```bash
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
```

Interdire `PermitRootLogin` force les administrateurs à se connecter avec leur compte personnel puis à élever les privilèges via `sudo`. Cela crée une **trace d'audit** : on sait qui a fait quoi, et quand.

> **Règle d'or :** toujours valider la syntaxe avec `sshd -t` et garder une session active avant de recharger SSH. Un fichier corrompu peut verrouiller l'accès au serveur.

---

## Règles réseau — `lib/network.sh`

### N-01 / N-02 : Politique de pare-feu

Le module génère un fichier de règles dans `/etc/hardening/firewall.rules` :

```text
DEFAULT_INPUT=deny
DEFAULT_OUTPUT=allow
ALLOW_TCP=22
ALLOW_TCP=80
ALLOW_TCP=443
```

Le principe est le **deny-by-default** : tout trafic entrant est bloqué sauf ce qui est explicitement autorisé. Seuls SSH (22), HTTP (80) et HTTPS (443) sont ouverts.

| Règle | Valeur | Raison |
| --- | --- | --- |
| `DEFAULT_INPUT` | `deny` | Bloque tout trafic entrant non autorisé |
| `DEFAULT_OUTPUT` | `allow` | Autorise les connexions sortantes |
| `ALLOW_TCP` | `22, 80, 443` | Ports nécessaires au fonctionnement minimal |

### N-03 : Durcissement du noyau via sysctl

```bash
echo "net.ipv4.ip_forward=0" >> /etc/sysctl.conf
echo "net.ipv4.icmp_echo_ignore_all=1" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf
```

| Paramètre | Valeur | Effet |
| --- | --- | --- |
| `net.ipv4.ip_forward` | `0` | Empêche le système de router des paquets entre interfaces |
| `net.ipv4.icmp_echo_ignore_all` | `1` | Ignore les requêtes ping (réduit la surface d'exposition) |

`sysctl -p` applique les paramètres immédiatement sans redémarrage. Le script utilise `|| true` pour ne pas échouer sur des environnements Docker avec un système de fichiers en lecture seule.

---

## Règles identité — `lib/identity.sh`

### I-01 : Politique de mots de passe

Le durcissement agit sur deux niveaux :

**1. `/etc/login.defs`** — politique globale des comptes :

```bash
sed -i "s/^PASS_MAX_DAYS.*/PASS_MAX_DAYS=90/" /etc/login.defs
sed -i "s/^PASS_MIN_LEN.*/PASS_MIN_LEN=12/" /etc/login.defs
```

**2. PAM (`/etc/pam.d/common-password`)** — complexité à la saisie :

```bash
echo "password requisite pam_pwquality.so minlen=12 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1" \
    >> /etc/pam.d/common-password
```

| Paramètre PAM | Valeur | Signification |
| --- | --- | --- |
| `minlen` | `12` | Longueur minimale de 12 caractères |
| `ucredit=-1` | `-1` | Au moins 1 majuscule requise |
| `lcredit=-1` | `-1` | Au moins 1 minuscule requise |
| `dcredit=-1` | `-1` | Au moins 1 chiffre requis |
| `ocredit=-1` | `-1` | Au moins 1 caractère spécial requis |

> Les valeurs négatives signifient "minimum requis". Une valeur positive signifierait un bonus accordé.

### I-02 : Verrouillage après tentatives échouées

```bash
echo "auth required pam_faillock.so deny=5" >> /etc/pam.d/common-auth
```

`pam_faillock` verrouille automatiquement un compte après N tentatives d'authentification échouées. Cela bloque les attaques par force brute sur les sessions locales et SSH avec mot de passe.

### I-03 : Suppression des utilisateurs non autorisés

```bash
for user in $(awk -F: '$3 > 1000 {print $1}' /etc/passwd); do
    if ! groups "$user" | grep -qE "sudo|wheel"; then
        userdel "$user"
    fi
done
```

Les comptes avec UID > 1000 sont des comptes utilisateurs standards. Tout compte dans cette plage qui n'appartient pas aux groupes `sudo` ou `wheel` est considéré non autorisé et supprimé.

> **Attention :** cette règle est destructive. En production, elle doit être adaptée pour conserver les comptes légitimes (comptes applicatifs, etc.).

### I-04 : Verrouillage du mot de passe root

```bash
passwd -l root
```

`passwd -l` préfixe le hash dans `/etc/shadow` avec `!`, ce qui invalide le mot de passe. Root reste accessible via `sudo` ou en console physique avec des mécanismes de récupération, mais ne peut plus s'authentifier directement par mot de passe.

---

## Règles système — `lib/system.sh`

### H-01 : Mise à jour des paquets

```bash
apt-get update && apt-get upgrade -y
```

La mise à jour systématique des paquets corrige les **CVE** (Common Vulnerabilities and Exposures) connus. C'est la règle de durcissement avec le meilleur rapport coût/bénéfice.

### H-02 : Suppression des outils dangereux

```bash
apt remove --purge telnet ftp netcat-traditional -y
apt autoremove --purge -y
```

| Outil | Risque |
| --- | --- |
| `telnet` | Protocole en clair — identifiants visibles par sniffing réseau |
| `ftp` | Même problème — données et credentials non chiffrés |
| `netcat-traditional` | Outil de tunneling réseau polyvalent, souvent utilisé pour les reverse shells |

`--purge` supprime aussi les fichiers de configuration, ce qui évite de laisser des configurations résiduelles.

### H-03 : Installation des outils de sécurité

```bash
apt-get install -y auditd fail2ban
```

| Outil | Rôle |
| --- | --- |
| `auditd` | Journalise les appels système critiques (accès fichiers, exécutions, changements d'identité) |
| `fail2ban` | Analyse les logs et bannit automatiquement les IPs responsables d'attaques par force brute |

---

## Rapport d'audit

À chaque exécution, `harden.sh` génère `audit_report.txt` avec le statut de chaque règle :

```text
===============================================
 HARDENING AUDIT REPORT - 2026-04-20T14:42:16Z
===============================================
[INFO] SSH configured on port 22
[INFO] Firewall policy created: ports 22, 80, 443 ALLOWED
[INFO] 0 unauthorized users removed
[WARN] Package updates skipped (already up to date).
[INFO] Removed: telnet, ftp, netcat-traditional.
[INFO] Installed: auditd, fail2ban.
===============================================
 COMPLIANCE STATUS: PASS
===============================================
```

Le statut final `PASS` / `FAIL` est déterminé par l'accumulation des erreurs rencontrées. Tout `[ERROR]` dans le rapport bascule le statut en `FAIL`.

**Fichiers :** `hardening/harden.sh`, `hardening/config/harden.cfg`, `hardening/lib/*.sh`
