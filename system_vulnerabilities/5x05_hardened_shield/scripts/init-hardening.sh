#!/bin/bash
# Petit script de durcissement lancé au démarrage du conteneur.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo '[ERROR] Lance ce script en root dans le conteneur.' >&2
    exit 1
fi

echo '=== System Hardening ==='

# Je règle les paramètres noyau vus dans le projet Bastion Host.
# Docker peut refuser certains paramètres. Je le signale pour les régler au lancement.
sysctl_rules=(
    'net.ipv4.ip_forward=0'
    'net.ipv4.conf.all.accept_redirects=0'
    'net.ipv4.conf.default.accept_redirects=0'
    'net.ipv4.conf.all.send_redirects=0'
    'net.ipv4.conf.default.send_redirects=0'
    'net.ipv4.conf.all.rp_filter=1'
    'net.ipv4.conf.default.rp_filter=1'
    'net.ipv4.tcp_syncookies=1'
    'net.ipv4.conf.all.accept_source_route=0'
    'net.ipv4.conf.default.accept_source_route=0'
    'net.ipv4.icmp_echo_ignore_broadcasts=1'
    'net.ipv4.conf.all.log_martians=1'
    'net.ipv4.conf.default.log_martians=1'
    'net.ipv6.conf.all.accept_redirects=0'
    'net.ipv6.conf.default.accept_redirects=0'
    'net.ipv6.conf.all.accept_source_route=0'
    'net.ipv6.conf.default.accept_source_route=0'
    'net.ipv6.conf.all.forwarding=0'
    'kernel.randomize_va_space=2'
    'kernel.kptr_restrict=2'
    'kernel.dmesg_restrict=1'
    'fs.suid_dumpable=0'
)

for rule in "${sysctl_rules[@]}"; do
    if ! sysctl -w "$rule" >/dev/null 2>&1; then
        echo "[WARN] $rule non modifiable ici; à régler avec Docker ou sur l'hôte."
    fi
done

# Je protège les dossiers temporaires et les fichiers qui contiennent des secrets.
chmod 1777 /tmp /var/tmp
for file in /etc/shadow /etc/gshadow /etc/ssh/ssh_host_*_key; do
    if [ -f "$file" ]; then
        chmod 600 "$file"
    fi
done

echo '[INFO] Ajouter noexec,nosuid,nodev aux montages temporaires dans Docker.'

# J'arrête quelques services inutiles s'ils sont installés.
# Je garde SSH, Nginx et Fail2ban, qui sont utilisés par le projet.
for service in avahi-daemon cups rpcbind postfix snapd; do
    if [ -x "/etc/init.d/$service" ]; then
        service "$service" stop >/dev/null 2>&1 || true
        if command -v update-rc.d >/dev/null 2>&1; then
            update-rc.d "$service" disable >/dev/null 2>&1 || true
        fi
        echo "[INFO] Service désactivé: $service"
    fi
done

# Je fais la liste des fichiers SUID/SGID pour pouvoir les vérifier.
find /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin \
    -type f \( -perm -4000 -o -perm -2000 \) -print 2>/dev/null \
    | sort -u > /run/hardened-shield-suid-audit.txt || {
        echo '[ERROR] Impossible de faire l’audit SUID/SGID.' >&2
        exit 2
    }
echo '[INFO] Résultat SUID/SGID: /run/hardened-shield-suid-audit.txt'

# J'affiche le même avertissement sur la console et lors d'une connexion SSH.
banner='Authorized access only. Activity may be monitored and recorded.'
for file in /etc/issue /etc/issue.net; do
    if [ ! -f "$file" ] || [ "$(cat "$file")" != "$banner" ]; then
        printf '%s\n' "$banner" > "$file" || {
            echo "[ERROR] Impossible d’écrire dans $file." >&2
            exit 3
        }
        chmod 644 "$file"
    fi
done

echo '[OK] Durcissement système terminé.'
exit 0
