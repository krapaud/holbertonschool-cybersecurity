#!/bin/bash
log() {
    echo "$(date -u +%FT%TZ) $1" >> /var/log/hardening.log
}
source config/harden.cfg
source lib/network.sh
source lib/ssh.sh
source lib/identity.sh
source lib/system.sh

if [ "$EUID" -ne 0 ]; then
    echo "Error: must be run as root"
    log "Error: must be run as root"
    exit 1
fi
log "Hardening framework initialized"
harden_ssh
harden_network
