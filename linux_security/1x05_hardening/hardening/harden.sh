#!/bin/bash
cd "$(dirname "$0")"
export DEBIAN_FRONTEND=noninteractive

# Global compliance status set to FAIL by any module on error
STATUS="PASS"

# Must run as root to modify system files
if [ "$EUID" -ne 0 ]; then
    echo "Error: must be run as root"
    log "Error: must be run as root"
    report "[ERROR]" "Must be run as root."
    exit 1
fi

# Load configuration and all library modules
source config/harden.cfg
source lib/network.sh
source lib/ssh.sh
source lib/identity.sh
source lib/system.sh

# Log function - writes timestamped messages to the hardening log
log() {
    echo "$(date -u +%FT%TZ) $1" >> /var/log/hardening.log
}
report() {
    echo "$1 $2" >> audit_report.txt
}

log "Hardening framework initialized"
echo "===============================================" > audit_report.txt
echo " HARDENING AUDIT REPORT - $(date '+%Y-%m-%d %H:%M:%S')" >> audit_report.txt
echo "===============================================" >> audit_report.txt
report "[INFO]" "Hardening procedure completed successfully."
harden_ssh
harden_network
harden_identity
harden_system
echo "===============================================" >> audit_report.txt
echo " COMPLIANCE STATUS: $STATUS" >> audit_report.txt
echo "===============================================" >> audit_report.txt
