#!/bin/bash

# Create the users, groups and limited sudo rights required by the project.
# This script is for Ubuntu and must be run as root.

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SUDOERS_FILE="/etc/sudoers.d/nexus-rbac"
BACKUP_DIR="/var/backups/nexus-rbac-$(date +%Y%m%d%H%M%S)"
LOG_FILE="/var/log/nexus-rbac.log"

# -----------------------------------------------------------------------------
# Small helper functions
# -----------------------------------------------------------------------------
log() {
    local message="$1"

    printf '%s %s\n' "$(date -u +%FT%TZ)" "$message" | tee -a "$LOG_FILE"
}

# -----------------------------------------------------------------------------
# Create a user only when it does not already exist.
# -----------------------------------------------------------------------------
create_user() {
    local username="$1"

    if ! id "$username" >/dev/null 2>&1; then
        useradd --create-home --user-group --shell /bin/bash "$username"
        passwd --lock "$username" >/dev/null
        log "Created locked user $username."
    fi
}

# -----------------------------------------------------------------------------
# Basic checks
# -----------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: rbac_setup.sh must be run as root." >&2
    exit 1
fi

for command in groupadd useradd usermod passwd visudo install; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Error: $command is not installed." >&2
        exit 1
    fi
done

# -----------------------------------------------------------------------------
# Prepare the backup and log
# -----------------------------------------------------------------------------
mkdir -p "$BACKUP_DIR"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"
log "Starting RBAC setup."

# -----------------------------------------------------------------------------
# Groups and users
# -----------------------------------------------------------------------------
groupadd --force devs
groupadd --force ops
groupadd --force auditors

if ! id sarah >/dev/null 2>&1; then
    useradd --create-home --user-group --shell /bin/bash sarah
    passwd --lock sarah >/dev/null
    log "Created locked user sarah."
fi

if ! id dave >/dev/null 2>&1; then
    useradd --create-home --user-group --shell /bin/bash dave
    passwd --lock dave >/dev/null
    log "Created locked user dave."
fi

create_user opsadmin

# Sarah is a developer with a limited Nginx operation.
usermod --append --groups devs sarah

# Dave is an auditor with read-only log access.
usermod --append --groups auditors dave

# opsadmin represents a normal operations administrator.
usermod --append --groups ops opsadmin

# -----------------------------------------------------------------------------
# Sudo permissions
# -----------------------------------------------------------------------------
mkdir -p "$(dirname "$SUDOERS_FILE")"
TEMP_SUDOERS="$(mktemp)"
trap 'rm -f "$TEMP_SUDOERS"' EXIT

cat > "$TEMP_SUDOERS" <<'EOF'
# Sarah can only check and restart Nginx.
sarah ALL=(root) NOPASSWD: /usr/bin/systemctl status nginx, \
    /usr/bin/systemctl restart nginx

# Dave can read selected service logs, but cannot edit configuration files.
dave ALL=(root) NOPASSWD: /usr/bin/journalctl -u nginx, \
    /usr/bin/journalctl -u postgresql
EOF

# Check the file before installing it in /etc/sudoers.d.
visudo -cf "$TEMP_SUDOERS"

if [ -e "$SUDOERS_FILE" ]; then
    cp -a "$SUDOERS_FILE" "$BACKUP_DIR/"
fi

install -o root -g root -m 0440 "$TEMP_SUDOERS" "$SUDOERS_FILE"
visudo -cf "$SUDOERS_FILE"
log "Installed and checked the sudoers file."

# -----------------------------------------------------------------------------
# Home directory permissions
# -----------------------------------------------------------------------------
for username in sarah dave opsadmin; do
    home_dir="/home/$username"

    if [ -d "$home_dir" ]; then
        chown "$username:$username" "$home_dir"
        chmod 700 "$home_dir"
    fi
done

log "Protected the user home directories with mode 700."
log "RBAC setup completed. Backups are in $BACKUP_DIR."
