#!/bin/bash

# N-01, N-02, N-03 - Harden network configuration
harden_network() {
    # N-01/N-02: Write firewall policy using values from config
    mkdir -p /etc/hardening/
    cat > /etc/hardening/firewall.rules << EOF
    DEFAULT_INPUT=deny
    DEFAULT_OUTPUT=allow
    ALLOW_TCP=$SSH_PORT
    ALLOW_TCP=$ALLOW_HTTP
    ALLOW_TCP=$ALLOW_HTTPS
EOF
    log "Firewall Rules created"

    # N-03: Disable IP forwarding to prevent packet routing
    if ! grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=0" >> /etc/sysctl.conf
        log "N-03: IP forwarding disabled"
    else
        sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward=0/' /etc/sysctl.conf
        log "N-03: IP forwarding already configured"
    fi

    # N-03: Ignore ICMP ping requests to reduce attack surface
    if ! grep -q "^net.ipv4.icmp_echo_ignore_all" /etc/sysctl.conf; then
        echo "net.ipv4.icmp_echo_ignore_all=1" >> /etc/sysctl.conf
        log "N-03: ICMP ignore enabled"
    else
        sed -i 's/^net.ipv4.icmp_echo_ignore_all.*/net.ipv4.icmp_echo_ignore_all=1/' /etc/sysctl.conf
        log "N-03: ICMP ignore already configured"
    fi
    report "[INFO]" "Firewall policy created: ports $SSH_PORT, $ALLOW_HTTP, $ALLOW_HTTPS ALLOWED"
    # N-03: Apply kernel parameters immediately without reboot
    sysctl -p /etc/sysctl.conf
}
