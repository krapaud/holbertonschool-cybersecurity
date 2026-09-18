#!/bin/bash

# Configure UFW so that the database and SSH are not open to everyone.
# This script is for Ubuntu and must be run as root.

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
# These are the lab addresses. Replace them with approved production
# addresses before using the script on a real network.
BACKUP_DIR="/var/backups/nexus-firewall-$(date +%Y%m%d%H%M%S)"
LOG_FILE="/var/log/nexus-firewall.log"

# -----------------------------------------------------------------------------
# Small helper function
# -----------------------------------------------------------------------------
log() {
    local message="$1"

    printf '%s %s\n' "$(date -u +%FT%TZ)" "$message" | tee -a "$LOG_FILE"
}

# -----------------------------------------------------------------------------
# Basic checks
# -----------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: network_defense.sh must be run as root." >&2
    exit 1
fi

if ! command -v ufw >/dev/null 2>&1; then
    echo "Error: ufw is not installed." >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# Prepare the backup and log
# -----------------------------------------------------------------------------
mkdir -p "$BACKUP_DIR"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

# Save the current rules before changing the firewall.
ufw status numbered > "$BACKUP_DIR/ufw-before.txt" || true
log "Saved the current UFW rules."

# -----------------------------------------------------------------------------
# Firewall rules
# -----------------------------------------------------------------------------
# Reset the lab firewall so an old public database rule cannot remain active.
# In production, review the current rules and maintenance window first.
ufw --force reset

# Deny incoming and routed traffic by default.
ufw default deny incoming
ufw default deny routed
ufw default allow outgoing

# SSH is allowed only from the bastion host.
ufw allow from 10.0.10.10 to any port 22 proto tcp

# PostgreSQL is allowed only from the private Web Server address.
ufw allow from 10.0.20.10 to any port 5432 proto tcp
ufw deny 5432/tcp

# Keep UFW logging useful without producing too many messages.
ufw logging low
ufw --force enable

log "UFW default-deny firewall rules are active."
ufw status verbose
