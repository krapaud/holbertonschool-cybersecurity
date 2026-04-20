#!/bin/bash
harden_system() {
    apt-get update && apt-get upgrade -y
    log "H-01: Update repositories and upgrade packages made"
    apt remove --purge telnet ftp netcat-traditional -y
    log "H-02: Uninstall telnet, ftp, netcat-traditional made"
    apt autoremove --purge -y
    log "H-02: Clean Orphelin dependance made"
    apt-get install -y auditd fail2ban
    log "H-03: Install auditd and fail2ban made"
}
