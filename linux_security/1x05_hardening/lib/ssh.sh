#!/bin/bash
harden_ssh() {
    if ! grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
        sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
        log "S-01: PasswordAuthentication disabled"
    else
        log "S-01: PasswordAuthentication already configured"
    fi
    if ! grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config; then
        sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
        log "S-01: PubkeyAuthentication enabled"
    else
        log "S-01: PubkeyAuthentication already configured"
    fi
    if ! grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
        sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
        log "S-02: PermitRootLogin disabled"
    else
        log "S-02: PermitRootLogin already configured"
    fi
}
