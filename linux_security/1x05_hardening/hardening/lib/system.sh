#!/bin/bash

# H-01 to H-03 - Harden system packages
harden_system() {
    # H-01: Update package lists and upgrade all packages
    apt-get update && apt-get upgrade -y
    log "H-01: Update repositories and upgrade packages made"
    report "[WARN]" "Package updates skipped (already up to date)."

    # H-02: Remove insecure legacy tools (clear-text protocols)
    apt remove --purge telnet ftp netcat-traditional -y
    log "H-02: Uninstall telnet, ftp, netcat-traditional made"
    apt autoremove --purge -y
    log "H-02: Clean Orphelin dependance made"
    report "[INFO]" "Removed: telnet, ftp, netcat-traditional."

    # H-03: Install security monitoring tools
    apt-get install -y auditd fail2ban
    log "H-03: Install auditd and fail2ban made"
    report "[INFO]" "Installed: auditd, fail2ban."
}
