#!/bin/bash

# S-01 and S-02 - Harden SSH configuration
# We use sed to modify existing lines or add them if missing
harden_ssh() {
    # S-01: Disable password auth - force public key only
    if ! grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
        sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
        log "S-01: PasswordAuthentication disabled"
    else
        log "S-01: PasswordAuthentication already configured"
    fi

    # S-01: Enable public key authentication
    if ! grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config; then
        sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
        log "S-01: PubkeyAuthentication enabled"
    else
        log "S-01: PubkeyAuthentication already configured"
    fi

    # S-02: Prevent root from logging in directly via SSH
    if ! grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
        sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
        log "S-02: PermitRootLogin disabled"
    else
        log "S-02: PermitRootLogin already configured"
    fi
}
