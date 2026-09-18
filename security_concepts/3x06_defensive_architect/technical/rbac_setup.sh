#!/bin/bash

# ============================================================================
# Nexus Financial RBAC setup
# ============================================================================
# This script creates the lab users and groups, installs restricted sudo
# rules, and protects user home directories.
#
# Sarah can restart Nginx without becoming root. Dave can read service logs,
# but neither account receives unrestricted administrative access.

set -euo pipefail

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------
SUDOERS_FILE="/etc/sudoers.d/nexus-rbac"
BACKUP_DIR="/var/backups/nexus-rbac-$(date +%Y%m%d%H%M%S)"
LOG_FILE="/var/log/nexus-rbac.log"
LOG_MODE="0600"

# ----------------------------------------------------------------------------
# Helper functions
# ----------------------------------------------------------------------------
log() {
    local message="$1"

    printf '%s %s\n' "$(date -u +%FT%TZ)" "$message" | tee -a "$LOG_FILE"
}

create_user_if_missing() {
    local username="$1"

    if ! id "$username" >/dev/null 2>&1; then
        useradd --create-home --user-group --shell /bin/bash "$username"
        passwd --lock "$username" >/dev/null
        log "Created locked lab user $username."
    fi
}

# ----------------------------------------------------------------------------
# Preconditions
# ----------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: rbac_setup.sh must be run as root." >&2
    exit 1
fi

for required_command in groupadd useradd usermod passwd visudo install; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        echo "Error: $required_command is not installed." >&2
        exit 1
    fi
done

# ----------------------------------------------------------------------------
# Prepare the backup directory and audit log
# ----------------------------------------------------------------------------
mkdir -p "$BACKUP_DIR"
touch "$LOG_FILE"
chmod "$LOG_MODE" "$LOG_FILE"
log "Starting Nexus Financial RBAC setup."

# ----------------------------------------------------------------------------
# Groups
# ----------------------------------------------------------------------------
# These are the simple role names required by the project brief.
groupadd --force devs
groupadd --force ops
groupadd --force auditors

# These additional groups keep the names used by the written policy.
groupadd --force nexus-dev
groupadd --force nexus-ops
groupadd --force nexus-auditor
groupadd --force nexus-web-operator
groupadd --force nexus-log-reader

# ----------------------------------------------------------------------------
# Dummy users and role membership
# ----------------------------------------------------------------------------
create_user_if_missing sarah
create_user_if_missing dave
create_user_if_missing opsadmin

# Sarah is a developer and a restricted web operator.
usermod --append --groups devs,nexus-dev sarah
usermod --append --groups nexus-web-operator sarah

# Dave is an auditor and can only use the restricted log-reading role.
usermod --append --groups auditors,nexus-auditor dave
usermod --append --groups nexus-log-reader dave

# This account represents a normal operations administrator.
usermod --append --groups ops,nexus-ops opsadmin

log "Created RBAC groups and assigned lab users."

# ----------------------------------------------------------------------------
# Restricted sudoers policy
# ----------------------------------------------------------------------------
# Sarah can check and restart Nginx only. She cannot open a root shell or edit
# Nginx configuration files through this sudoers entry.
# Dave can read selected service logs only. No configuration command is given.
mkdir -p "$(dirname "$SUDOERS_FILE")"
TEMP_SUDOERS="$(mktemp)"
trap 'rm -f "$TEMP_SUDOERS"' EXIT

cat > "$TEMP_SUDOERS" <<'EOF'
# Managed by Nexus Financial rbac_setup.sh

# Sarah: limited Nginx operation without unrestricted root access.
sarah ALL=(root) NOPASSWD: /usr/bin/systemctl status nginx, \
    /usr/bin/systemctl restart nginx

# Dave: read-only access to selected service logs.
dave ALL=(root) NOPASSWD: /usr/bin/journalctl -u nginx, \
    /usr/bin/journalctl -u postgresql

# The role groups provide the same controlled permissions for future members.
%nexus-web-operator ALL=(root) NOPASSWD: /usr/bin/systemctl status nginx, \
    /usr/bin/systemctl restart nginx
%nexus-log-reader ALL=(root) NOPASSWD: /usr/bin/journalctl -u nginx, \
    /usr/bin/journalctl -u postgresql
EOF

# Never install a sudoers file before its syntax has been checked.
visudo -cf "$TEMP_SUDOERS"

if [ -e "$SUDOERS_FILE" ]; then
    cp -a "$SUDOERS_FILE" "$BACKUP_DIR/"
fi

install -o root -g root -m 0440 "$TEMP_SUDOERS" "$SUDOERS_FILE"
visudo -cf "$SUDOERS_FILE"
log "Installed and validated $SUDOERS_FILE."

# ----------------------------------------------------------------------------
# Home directory permissions
# ----------------------------------------------------------------------------
# Users own their homes, but other local users must not be able to browse them.
for username in sarah dave opsadmin; do
    home_dir="/home/$username"

    if [ -d "$home_dir" ]; then
        chown "$username:$username" "$home_dir"
        chmod 700 "$home_dir"
    fi
done

log "Applied mode 700 to lab home directories."
log "RBAC setup completed. Backups are stored in $BACKUP_DIR."
