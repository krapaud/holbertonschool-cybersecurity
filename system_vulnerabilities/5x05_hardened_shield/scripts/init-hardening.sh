#!/bin/bash
# Applique les contrôles système disponibles depuis le conteneur.
set -Eeuo pipefail

error() { printf '[init-hardening][ERROR] %s\n' "$1" >&2; exit 1; }
info() { printf '[init-hardening] %s\n' "$1"; }
warning() { printf '[init-hardening][WARN] %s\n' "$1" >&2; }

for tool in awk cat chmod find id install mktemp rm sort; do
    command -v "$tool" >/dev/null 2>&1 || error "Required command not found: $tool"
done
[ "$(id -u)" -eq 0 ] || error 'Run this script as root inside the container.'

# Ces valeurs sont réappliquées sans doublons et persistent si le fichier est
# accessible. Docker ou l'hôte peut bloquer sysctl dans le namespace noyau.
settings=(
    net.ipv4.ip_forward=0
    net.ipv4.conf.all.accept_redirects=0
    net.ipv4.conf.default.accept_redirects=0
    net.ipv4.conf.all.send_redirects=0
    net.ipv4.conf.default.send_redirects=0
    net.ipv4.conf.all.rp_filter=1
    net.ipv4.conf.default.rp_filter=1
    net.ipv4.tcp_syncookies=1
    net.ipv4.conf.all.accept_source_route=0
    net.ipv4.conf.default.accept_source_route=0
    net.ipv4.icmp_echo_ignore_broadcasts=1
    net.ipv4.conf.all.log_martians=1
    net.ipv4.conf.default.log_martians=1
    net.ipv6.conf.all.accept_redirects=0
    net.ipv6.conf.default.accept_redirects=0
    net.ipv6.conf.all.accept_source_route=0
    net.ipv6.conf.default.accept_source_route=0
    net.ipv6.conf.all.forwarding=0
    kernel.randomize_va_space=2
    kernel.kptr_restrict=2
    kernel.dmesg_restrict=1
    fs.suid_dumpable=0
)
if [ -d /proc/sys ]; then
    for setting in "${settings[@]}"; do
        key=${setting%%=*}
        value=${setting#*=}
        sysctl -w "$key=$value" >/dev/null 2>&1 || \
            warning "$key is not writable; configure it with Docker --sysctl or on the host."
    done
    if [ -w /etc/sysctl.d ]; then
        temporary=$(mktemp /etc/sysctl.d/99-hardened-shield.XXXXXX) || \
            error 'Could not prepare persistent sysctl settings.'
        for setting in "${settings[@]}"; do
            printf '%s = %s\n' "${setting%%=*}" "${setting#*=}" >> "$temporary"
        done
        install -o root -g root -m 0644 "$temporary" /etc/sysctl.d/99-hardened-shield.conf || {
            rm -f -- "$temporary"
            error 'Could not install persistent sysctl settings.'
        }
        rm -f -- "$temporary"
    else
        warning 'Filesystem is read-only; persistent sysctl configuration belongs to Docker or the host.'
    fi
else
    warning '/proc/sys is unavailable; kernel controls must be set by Docker or the host.'
fi
info 'Kernel parameter configuration checked.'

# Les répertoires temporaires gardent le sticky bit. Les flags noexec, nosuid
# et nodev relèvent du montage Docker et sont signalés si absents.
for directory in /tmp /var/tmp; do
    [ ! -d "$directory" ] || chmod 1777 "$directory" || \
        warning "Could not set sticky permissions on $directory."
done
for protected_file in /etc/shadow /etc/gshadow /etc/ssh/ssh_host_*_key; do
    [ ! -e "$protected_file" ] || chmod 0600 "$protected_file" || \
        warning "Could not protect $protected_file."
done
if command -v findmnt >/dev/null 2>&1; then
    for directory in /tmp /var/tmp /dev/shm; do
        [ ! -e "$directory" ] && continue
        if ! findmnt -n -o OPTIONS --target "$directory" 2>/dev/null | \
            awk -F, '{ for (i = 1; i <= NF; i++) if ($i == "noexec") ok = 1 } END { exit !ok }'; then
            warning "$directory lacks noexec; mount it as noexec,nosuid,nodev in Docker."
        fi
    done
fi
info 'Filesystem permissions checked; mount flags must be set by Docker.'

# Seuls les services facultatifs connus sont arrêtés. SSH, Nginx, rsyslog et
# Fail2ban sont conservés car ils sont requis par ce projet.
for service_name in avahi-daemon cups rpcbind postfix snapd; do
    [ -x "/etc/init.d/$service_name" ] || continue
    if command -v systemctl >/dev/null 2>&1 && \
        systemctl is-system-running >/dev/null 2>&1; then
        systemctl disable --now "$service_name" >/dev/null 2>&1 || \
            warning "Could not stop and disable $service_name."
    elif command -v service >/dev/null 2>&1; then
        service "$service_name" stop >/dev/null 2>&1 || true
        if command -v update-rc.d >/dev/null 2>&1; then
            update-rc.d "$service_name" disable >/dev/null 2>&1 || \
                warning "Could not disable startup for $service_name."
        fi
    fi
    info "Optional service minimized: $service_name"
done

# Inventaire SUID/SGID pour revue, sans supprimer à l'aveugle des bits requis.
scan_roots=()
for directory in /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin; do
    [ ! -d "$directory" ] || scan_roots+=("$directory")
done
if [ "${#scan_roots[@]}" -gt 0 ] && [ -w /run ]; then
    audit_file=/run/hardened-shield-suid-audit.txt
    find "${scan_roots[@]}" -xdev -type f \
        \( -perm -4000 -o -perm -2000 \) -print 2>/dev/null | sort -u > "$audit_file" || \
        warning 'SUID/SGID inventory was incomplete.'
    chmod 0600 "$audit_file" 2>/dev/null || true
    info "SUID/SGID inventory saved to $audit_file."
    while IFS= read -r path; do info "Review SUID/SGID file: $path"; done < "$audit_file"
else
    warning 'SUID/SGID audit skipped because standard paths or /run are unavailable.'
fi

# Le même avis est installé sur la console et affiché par OpenSSH.
banner='Authorized access only. Activity may be monitored and recorded.'
for banner_file in /etc/issue /etc/issue.net; do
    if [ -f "$banner_file" ] && [ "$(cat "$banner_file")" = "$banner" ]; then
        continue
    fi
    [ -w "$(dirname "$banner_file")" ] || {
        warning "$banner_file is read-only; include the banner during image build."
        continue
    }
    temporary=$(mktemp "${banner_file}.XXXXXX") || error "Could not prepare $banner_file."
    printf '%s\n' "$banner" > "$temporary"
    install -o root -g root -m 0644 "$temporary" "$banner_file" || {
        rm -f -- "$temporary"
        error "Could not install $banner_file."
    }
    rm -f -- "$temporary"
done
info 'Legal banner configured.'
info 'System hardening initialization finished.'
