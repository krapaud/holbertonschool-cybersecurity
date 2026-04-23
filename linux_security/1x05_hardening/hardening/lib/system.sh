#!/bin/bash

# H-01 to H-03 - Harden system packages
harden_system() {
    # H-01: Update package lists and upgrade all packages
    if ! apt-get update && apt-get upgrade -y; then
        log "H-01: Failed to update/upgrade packages"
        report "[ERROR]" "Package update failed."
        STATUS="FAIL"
    else
        log "H-01: Update repositories and upgrade packages made"
        report "[WARN]" "Package updates skipped (already up to date)."
    fi

    # H-02: Remove insecure legacy tools (clear-text protocols)
    apt remove --purge telnet ftp netcat-traditional -y
    log "H-02: Uninstall telnet, ftp, netcat-traditional made"
    apt autoremove --purge -y
    log "H-02: Clean Orphelin dependance made"
    report "[INFO]" "Removed: telnet, ftp, netcat-traditional."

    # H-03: Install security monitoring tools
    if ! apt-get install -y auditd fail2ban; then
        log "H-03: Failed to install auditd and fail2ban"
        report "[ERROR]" "Failed to install security tools."
        STATUS="FAIL"
    else
        log "H-03: Install auditd and fail2ban made"
        report "[INFO]" "Installed: auditd, fail2ban."
    fi
}
