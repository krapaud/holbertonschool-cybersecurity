#!/bin/bash

# Send important logs to a central server and monitor security changes.
# This script is for Ubuntu and must be run as root.

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
RSYSLOG_FILE="/etc/rsyslog.d/60-nexus-central.conf"
AUDIT_RULES_FILE="/etc/audit/rules.d/nexus.rules"
BACKUP_DIR="/var/backups/nexus-logging-$(date +%Y%m%d%H%M%S)"
LOG_FILE="/var/log/nexus-logging.log"

# -----------------------------------------------------------------------------
# Small helper functions
# -----------------------------------------------------------------------------
log() {
    local message="$1"

    printf '%s %s\n' "$(date -u +%FT%TZ)" "$message" | tee -a "$LOG_FILE"
}

# Save an existing configuration before replacing it.
backup_file() {
    local file="$1"

    if [ -e "$file" ]; then
        cp -a "$file" "$BACKUP_DIR/"
    fi
}

# -----------------------------------------------------------------------------
# Basic checks
# -----------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: logging_setup.sh must be run as root." >&2
    exit 1
fi

for command in rsyslogd auditd augenrules auditctl; do
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
log "Starting logging setup."

# -----------------------------------------------------------------------------
# Central rsyslog forwarding
# -----------------------------------------------------------------------------
mkdir -p "$(dirname "$RSYSLOG_FILE")"
backup_file "$RSYSLOG_FILE"

# 10.0.40.10 is the central logging server in this lab.
cat > "$RSYSLOG_FILE" <<'EOF'
# Send critical and authentication logs to the central server.
*.crit @@10.0.40.10:514
auth,authpriv.* @@10.0.40.10:514
EOF

# Check the rsyslog configuration before reloading the service.
rsyslogd -N1
systemctl enable rsyslog
systemctl reload rsyslog
log "Configured rsyslog forwarding to 10.0.40.10."

# -----------------------------------------------------------------------------
# auditd rules
# -----------------------------------------------------------------------------
mkdir -p "$(dirname "$AUDIT_RULES_FILE")"
backup_file "$AUDIT_RULES_FILE"

cat > "$AUDIT_RULES_FILE" <<'EOF'
# Monitor identity, SSH and sudo configuration files.
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/sudoers -p wa -k sudo_changes
-w /etc/sudoers.d/ -p wa -k sudo_changes
-w /etc/ssh/sshd_config -p wa -k ssh_changes
-w /etc/ssh/sshd_config.d/ -p wa -k ssh_changes

# Record execution of commands with root privileges.
-a always,exit -F arch=b64 -S execve -F euid=0 -k privileged_commands
-a always,exit -F arch=b32 -S execve -F euid=0 -k privileged_commands

# Keep the audit configuration immutable until the next reboot.
-e 2
EOF

# Load the rules and verify that auditd accepted them.
augenrules --check
augenrules --load
systemctl enable auditd

if ! auditctl -s | grep -q 'enabled 2'; then
    echo "Error: auditd is not immutable." >&2
    exit 1
fi

log "Configured auditd and enabled immutable audit rules."
log "Logging setup completed. Backups are in $BACKUP_DIR."
