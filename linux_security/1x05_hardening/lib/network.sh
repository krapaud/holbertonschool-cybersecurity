#!/bin/bash
mkdir -p /etc/hardening/
harden_network() {
    cat > /etc/hardening/firewall.rules << EOF
    DEFAULT_INPUT=deny
    DEFAULT_OUTPUT=allow
    ALLOW_TCP=$SSH_PORT
    ALLOW_TCP=$ALLOW_HTTP
    ALLOW_TCP=$ALLOW_HTTPS
EOF
    log "Firewall Rules created"
    if ! grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=0" >> /etc/sysctl.conf
        log "N-03: IP forwarding disabled"
    else
        sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward=0/' /etc/sysctl.conf
        log "N-03: IP forwarding already configured"
    fi
    if ! grep -q "^net.ipv4.icmp_echo_ignore_all" /etc/sysctl.conf; then
        echo "net.ipv4.icmp_echo_ignore_all=1" >> /etc/sysctl.conf
        log "N-03: ICMP ignore enabled"
    else
        sed -i 's/^net.ipv4.icmp_echo_ignore_all.*/net.ipv4.icmp_echo_ignore_all=1/' /etc/sysctl.conf
        log "N-03: ICMP ignore already configured"
    fi
}
