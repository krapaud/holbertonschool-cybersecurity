#!/bin/bash

# Apply the basic security settings defined in the project policy.
# This script is for Ubuntu and must be run as root.

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
# Load the values stored in the configuration file next to this script.
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
CONFIG_FILE="${HARDENING_CONFIG:-$SCRIPT_DIR/hardening.conf}"

if [ ! -r "$CONFIG_FILE" ]; then
    echo "Error: hardening.conf was not found." >&2
    exit 1
fi

# shellcheck disable=SC1090
. "$CONFIG_FILE"

BACKUP_DIR="$BACKUP_ROOT/nexus-hardening-$(date +%Y%m%d%H%M%S)"

# -----------------------------------------------------------------------------
# Small helper functions
# -----------------------------------------------------------------------------
log() {
    local message="$1"

    printf '%s %s\n' "$(date -u +%FT%TZ)" "$message" | tee -a "$LOG_FILE"
}

backup_file() {
    local file="$1"

    if [ -e "$file" ]; then
        cp -a "$file" "$BACKUP_DIR/"
    fi
}

# -----------------------------------------------------------------------------
# Basic checks
# -----------------------------------------------------------------------------
# The script changes files under /etc, so root privileges are required.
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: hardening.sh must be run as root." >&2
    exit 1
fi

if ! command -v sshd >/dev/null 2>&1; then
    echo "Error: sshd is not installed." >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# Prepare the backup and log
# -----------------------------------------------------------------------------
mkdir -p "$BACKUP_DIR"
touch "$LOG_FILE"
chmod "$LOG_MODE" "$LOG_FILE"
log "Starting system hardening."

# Do not disable password login if no administrator key is installed.
admin_key_found=false
while IFS= read -r key_file; do
    if [ -s "$key_file" ]; then
        admin_key_found=true
        break
    fi
done < <(find $KEY_SEARCH_PATHS -type f \
    -path '*/.ssh/authorized_keys' 2>/dev/null)

if [ "$admin_key_found" = false ]; then
    log "No authorized_keys file was found. SSH was not changed."
    exit 1
fi

# -----------------------------------------------------------------------------
# SSH settings
# -----------------------------------------------------------------------------
mkdir -p "$(dirname "$SSHD_DROPIN")"
backup_file "$SSHD_DROPIN"
backup_file "$SSHD_CONFIG_FILE"

# These values are deliberately written directly because they are mandatory.
cat > "$SSHD_DROPIN" <<EOF
# Managed by hardening.sh
PubkeyAuthentication yes
PasswordAuthentication no
PermitRootLogin no
PermitEmptyPasswords $SSH_PERMIT_EMPTY_PASSWORDS
X11Forwarding $SSH_X11_FORWARDING
EOF

# Check the generated file before reloading SSH.
grep -q '^PermitRootLogin no$' "$SSHD_DROPIN"
grep -q '^PasswordAuthentication no$' "$SSHD_DROPIN"
grep -q '^PubkeyAuthentication yes$' "$SSHD_DROPIN"

chown root:root "$SSHD_DROPIN" "$SSHD_CONFIG_FILE"
chmod "$SYSTEM_CONFIG_MODE" "$SSHD_DROPIN" "$SSHD_CONFIG_FILE"
sshd -t

for service in $SSH_SERVICES; do
    if systemctl is-active --quiet "$service"; then
        systemctl reload "$service"
        log "Reloaded $service."
        break
    fi
done

# Protect SSH directories and authorized_keys files already on the server.
while IFS= read -r ssh_dir; do
    chmod "$SSH_DIRECTORY_MODE" "$ssh_dir"
done < <(find $KEY_SEARCH_PATHS -type d -name .ssh 2>/dev/null)

while IFS= read -r authorized_keys; do
    chmod "$AUTHORIZED_KEYS_MODE" "$authorized_keys"
done < <(find $KEY_SEARCH_PATHS -type f \
    -path '*/.ssh/authorized_keys' 2>/dev/null)

# -----------------------------------------------------------------------------
# Kernel and network settings
# -----------------------------------------------------------------------------
mkdir -p "$(dirname "$SYSCTL_DROPIN")"
backup_file "$SYSCTL_DROPIN"

cat > "$SYSCTL_DROPIN" <<EOF
# Managed by hardening.sh
kernel.randomize_va_space = $KERNEL_RANDOMIZE_VA_SPACE
net.ipv4.conf.all.accept_redirects = $IPV4_ALL_ACCEPT_REDIRECTS
net.ipv4.conf.default.accept_redirects = $IPV4_DEFAULT_ACCEPT_REDIRECTS
net.ipv4.conf.all.accept_source_route = $IPV4_ALL_ACCEPT_SOURCE_ROUTE
net.ipv4.conf.default.accept_source_route = $IPV4_DEFAULT_ACCEPT_SOURCE_ROUTE
net.ipv4.conf.all.send_redirects = $IPV4_ALL_SEND_REDIRECTS
net.ipv4.conf.default.send_redirects = $IPV4_DEFAULT_SEND_REDIRECTS
net.ipv4.conf.all.rp_filter = $IPV4_ALL_RP_FILTER
net.ipv4.icmp_echo_ignore_broadcasts = \
$IPV4_ICMP_ECHO_IGNORE_BROADCASTS
EOF

chown root:root "$SYSCTL_DROPIN"
chmod "$SYSTEM_CONFIG_MODE" "$SYSCTL_DROPIN"
sysctl --system >/dev/null

# -----------------------------------------------------------------------------
# Default permissions for new files
# -----------------------------------------------------------------------------
backup_file "$UMASK_DROPIN"

cat > "$UMASK_DROPIN" <<EOF
# Managed by hardening.sh
umask $DEFAULT_UMASK
EOF

chown root:root "$UMASK_DROPIN"
chmod "$SYSTEM_CONFIG_MODE" "$UMASK_DROPIN"
log "Default umask set to $DEFAULT_UMASK."
log "Hardening completed. Backups are in $BACKUP_DIR."
