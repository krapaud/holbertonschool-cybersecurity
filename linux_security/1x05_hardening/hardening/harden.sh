#!/bin/bash
cd "$(dirname "$0")"
export DEBIAN_FRONTEND=noninteractive

# Log function - writes timestamped messages to the hardening log
log() {
    echo "$(date -u +%FT%TZ) $1" >> /var/log/hardening.log
}

# Load configuration and all library modules
source config/harden.cfg
source lib/network.sh
source lib/ssh.sh
source lib/identity.sh
source lib/system.sh

# Must run as root to modify system files
if [ "$EUID" -ne 0 ]; then
    echo "Error: must be run as root"
    log "Error: must be run as root"
    exit 1
fi

log "Hardening framework initialized"
harden_ssh
harden_network
harden_identity
harden_system
