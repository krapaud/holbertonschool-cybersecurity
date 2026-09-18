#!/bin/bash

# ============================================================================
# Nexus Financial system hardening
# ============================================================================
# This script applies the secure baseline described in the access control
# policy. It is intended for Ubuntu servers and must be run as root.
#
# The script keeps the operating system running, validates SSH before reload,
# and stores backups before changing managed configuration files.

set -euo pipefail

# ----------------------------------------------------------------------------
# Load configuration and validate required values
# ----------------------------------------------------------------------------
# The default file is next to this script. A different file can be supplied
# with HARDENING_CONFIG=/path/to/file.conf when testing another baseline.
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
CONFIG_FILE="${HARDENING_CONFIG:-$SCRIPT_DIR/hardening.conf}"

if [ ! -r "$CONFIG_FILE" ]; then
    echo "Error: configuration file not found: $CONFIG_FILE" >&2
    exit 1
fi

# The configuration file contains trusted shell variables, not secrets.
# shellcheck disable=SC1090
. "$CONFIG_FILE"

require_config() {
    local variable="$1"

    if [ -z "${!variable:-}" ]; then
        echo "Error: missing configuration value: $variable" >&2
        exit 1
    fi
}

for config_variable in \
    SSHD_CONFIG_FILE SSHD_DROPIN SYSCTL_DROPIN UMASK_DROPIN BACKUP_ROOT \
    LOG_FILE SSH_SERVICES KEY_SEARCH_PATHS SSH_PUBKEY_AUTHENTICATION \
    SSH_PASSWORD_AUTHENTICATION SSH_PERMIT_ROOT_LOGIN \
    SSH_PERMIT_EMPTY_PASSWORDS SSH_X11_FORWARDING KERNEL_RANDOMIZE_VA_SPACE \
    IPV4_ALL_ACCEPT_REDIRECTS IPV4_DEFAULT_ACCEPT_REDIRECTS \
    IPV4_ALL_ACCEPT_SOURCE_ROUTE IPV4_DEFAULT_ACCEPT_SOURCE_ROUTE \
    IPV4_ALL_SEND_REDIRECTS IPV4_DEFAULT_SEND_REDIRECTS \
    IPV4_ALL_RP_FILTER IPV4_ICMP_ECHO_IGNORE_BROADCASTS DEFAULT_UMASK \
    SSH_DIRECTORY_MODE AUTHORIZED_KEYS_MODE SYSTEM_CONFIG_MODE LOG_MODE; do
    require_config "$config_variable"
done

# These three SSH values are mandatory security controls from the policy.
# PermitRootLogin no
# PasswordAuthentication no
# PubkeyAuthentication yes
if [ "$SSH_PERMIT_ROOT_LOGIN" != "no" ] || \
    [ "$SSH_PASSWORD_AUTHENTICATION" != "no" ] || \
    [ "$SSH_PUBKEY_AUTHENTICATION" != "yes" ]; then
    echo "Error: mandatory SSH baseline values were changed." >&2
    exit 1
fi

BACKUP_DIR="$BACKUP_ROOT/nexus-hardening-$(date +%Y%m%d%H%M%S)"

# ----------------------------------------------------------------------------
# Helper functions
# ----------------------------------------------------------------------------
# Write a UTC timestamp to the terminal and to the hardening log.
log() {
    local message="$1"

    printf '%s %s\n' "$(date -u +%FT%TZ)" "$message" | tee -a "$LOG_FILE"
}

# Back up an existing file before the script replaces it.
backup_file() {
    local file="$1"

    if [ -e "$file" ]; then
        cp -a "$file" "$BACKUP_DIR/"
    fi
}

# ----------------------------------------------------------------------------
# Preconditions
# ----------------------------------------------------------------------------
# Root privileges are required to change SSH, sysctl and profile settings.
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: hardening.sh must be run as root." >&2
    exit 1
fi

# Refuse to continue if the SSH server is not installed.
if ! command -v sshd >/dev/null 2>&1; then
    echo "Error: sshd is not installed." >&2
    exit 1
fi

# ----------------------------------------------------------------------------
# Prepare the backup directory and audit log
# ----------------------------------------------------------------------------
mkdir -p "$BACKUP_DIR"
touch "$LOG_FILE"
chmod "$LOG_MODE" "$LOG_FILE"
log "Starting Nexus Financial system hardening."

# ----------------------------------------------------------------------------
# SSH access hardening
# ----------------------------------------------------------------------------
# Do not disable password authentication if no usable administrator key exists.
# This check prevents the script from locking administrators out of the server.
admin_key_count=0
while IFS= read -r key_file; do
    if [ -s "$key_file" ]; then
        admin_key_count=$((admin_key_count + 1))
    fi
done < <(find $KEY_SEARCH_PATHS -type f -path '*/.ssh/authorized_keys' \
    2>/dev/null)

if [ "$admin_key_count" -eq 0 ]; then
    log "ERROR: no authorized_keys file was found."
    log "SSH changes were not applied."
    exit 1
fi

# Write a separate drop-in so the distribution's main sshd_config stays easy
# to manage and the hardening settings can be reviewed in one place.
mkdir -p "$(dirname "$SSHD_DROPIN")"
backup_file "$SSHD_DROPIN"
backup_file "$SSHD_CONFIG_FILE"

cat > "$SSHD_DROPIN" <<EOF
# Managed by Nexus Financial hardening.sh
PubkeyAuthentication $SSH_PUBKEY_AUTHENTICATION
PasswordAuthentication $SSH_PASSWORD_AUTHENTICATION
PermitRootLogin $SSH_PERMIT_ROOT_LOGIN
PermitEmptyPasswords $SSH_PERMIT_EMPTY_PASSWORDS
X11Forwarding $SSH_X11_FORWARDING
EOF

chown root:root "$SSHD_DROPIN" "$SSHD_CONFIG_FILE"
chmod "$SYSTEM_CONFIG_MODE" "$SSHD_DROPIN" "$SSHD_CONFIG_FILE"

# Always validate the complete SSH configuration before reloading the service.
# A failed validation stops the script before the running service is changed.
sshd -t
log "SSH configuration validated."

# Reload SSH instead of restarting it, so existing connections are preserved.
for ssh_service in $SSH_SERVICES; do
    if systemctl list-unit-files "${ssh_service}.service" \
        >/dev/null 2>&1 && systemctl is-active --quiet "$ssh_service"; then
        systemctl reload "$ssh_service"
        log "Reloaded $ssh_service."
        break
    fi
done

# ----------------------------------------------------------------------------
# SSH key file permissions
# ----------------------------------------------------------------------------
# Private SSH directories and authorized_keys files must not be writable by
# other users. Ownership is preserved for each user's existing SSH directory.
while IFS= read -r ssh_dir; do
    chmod "$SSH_DIRECTORY_MODE" "$ssh_dir"
    owner="$(stat -c '%U:%G' "$ssh_dir")"
    chown "$owner" "$ssh_dir"
done < <(find $KEY_SEARCH_PATHS -type d -name .ssh 2>/dev/null)

while IFS= read -r authorized_keys; do
    chmod "$AUTHORIZED_KEYS_MODE" "$authorized_keys"
    owner="$(stat -c '%U:%G' "$(dirname "$authorized_keys")")"
    chown "$owner" "$authorized_keys"
done < <(find $KEY_SEARCH_PATHS -type f -path '*/.ssh/authorized_keys' \
    2>/dev/null)

# ----------------------------------------------------------------------------
# Kernel and network stack hardening
# ----------------------------------------------------------------------------
# These settings reduce exposure to spoofing, unsafe redirects and broadcast
# abuse while keeping normal server networking available.
mkdir -p "$(dirname "$SYSCTL_DROPIN")"
backup_file "$SYSCTL_DROPIN"
cat > "$SYSCTL_DROPIN" <<EOF
# Managed by Nexus Financial hardening.sh
kernel.randomize_va_space = $KERNEL_RANDOMIZE_VA_SPACE
net.ipv4.conf.all.accept_redirects = $IPV4_ALL_ACCEPT_REDIRECTS
net.ipv4.conf.default.accept_redirects = $IPV4_DEFAULT_ACCEPT_REDIRECTS
net.ipv4.conf.all.accept_source_route = $IPV4_ALL_ACCEPT_SOURCE_ROUTE
net.ipv4.conf.default.accept_source_route = \
$IPV4_DEFAULT_ACCEPT_SOURCE_ROUTE
net.ipv4.conf.all.send_redirects = $IPV4_ALL_SEND_REDIRECTS
net.ipv4.conf.default.send_redirects = $IPV4_DEFAULT_SEND_REDIRECTS
net.ipv4.conf.all.rp_filter = $IPV4_ALL_RP_FILTER
net.ipv4.icmp_echo_ignore_broadcasts = \
$IPV4_ICMP_ECHO_IGNORE_BROADCASTS
EOF

chown root:root "$SYSCTL_DROPIN"
chmod "$SYSTEM_CONFIG_MODE" "$SYSCTL_DROPIN"
sysctl --system >/dev/null
log "Kernel network and memory protections applied."

# ----------------------------------------------------------------------------
# Secure default file permissions
# ----------------------------------------------------------------------------
# New interactive files will not be readable by other local users by default.
backup_file "$UMASK_DROPIN"
cat > "$UMASK_DROPIN" <<EOF
# Managed by Nexus Financial hardening.sh
umask $DEFAULT_UMASK
EOF

chown root:root "$UMASK_DROPIN"
chmod "$SYSTEM_CONFIG_MODE" "$UMASK_DROPIN"
log "Default user umask set to $DEFAULT_UMASK."

# ----------------------------------------------------------------------------
# Completion
# ----------------------------------------------------------------------------
log "Hardening completed successfully. Backups are stored in $BACKUP_DIR."
