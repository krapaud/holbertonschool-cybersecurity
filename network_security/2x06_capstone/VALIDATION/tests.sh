#!/bin/bash
# tests.sh - Automated compliance checks for LogiCorp Gateway
# Verifies that all hardening steps from HARDENING/ have been applied correctly.
# Run as root. Each check prints [PASS] or [FAIL] and a final score.

set -uo pipefail

# Load expected values from the hardening config so both scripts stay in sync
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../HARDENING/config.sh"

PASS=0
FAIL=0

# Helper: run a command silently and print [PASS] or [FAIL] with the description
check() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "[PASS] $description"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $description"
        FAIL=$((FAIL + 1))
    fi
}

# Helper: check that a string does NOT appear in a command's output
check_absent() {
    local description="$1"
    local pattern="$2"
    shift 2
    if "$@" 2>/dev/null | grep -q "$pattern"; then
        echo "[FAIL] $description"
        FAIL=$((FAIL + 1))
    else
        echo "[PASS] $description"
        PASS=$((PASS + 1))
    fi
}

echo "======================================================"
echo " LogiCorp Gateway - Compliance Check"
echo "======================================================"
echo ""

# ------------------------------------------------------
# Firewall checks
# We verify that nftables is running with the expected
# default-deny policy and that the required rules exist.
# ------------------------------------------------------
echo "--- Firewall ---"

check "Firewall default INPUT policy is DROP" \
    bash -c "nft list chain inet filter input 2>/dev/null | grep -q 'policy drop'"

check "Firewall default FORWARD policy is DROP" \
    bash -c "nft list chain inet filter forward 2>/dev/null | grep -q 'policy drop'"

check "WireGuard port $VPN_PORT is open in INPUT" \
    bash -c "nft list ruleset 2>/dev/null | grep -q 'dport $VPN_PORT'"

check "SSH port $SSH_PORT is restricted to VPN subnet only" \
    bash -c "nft list ruleset 2>/dev/null | grep -q 'saddr.*$VPN_SUBNET.*dport $SSH_PORT'"

check "FTP port $FTP_PORT is restricted to VPN subnet only" \
    bash -c "nft list ruleset 2>/dev/null | grep -q 'saddr.*$VPN_SUBNET.*dport $FTP_PORT'"

check "NAT masquerade is configured for VPN traffic" \
    bash -c "nft list ruleset 2>/dev/null | grep -q 'masquerade'"

check_absent "SSH port is NOT open directly from the internet" \
    "dport $SSH_PORT accept" \
    bash -c "nft list chain inet filter input 2>/dev/null | grep -v 'saddr'"

echo ""

# ------------------------------------------------------
# Service checks
# SSH and VPN must be running. ttyd and openvscode-server
# must be stopped since they expose root shells in a browser.
# ------------------------------------------------------
echo "--- Services ---"

check "SSH is running" \
    pgrep sshd

check "FTP server (vsftpd) is running" \
    pgrep vsftpd

check "VPN interface $WG_IFACE is UP" \
    wg show "$WG_IFACE"

check_absent "ttyd is NOT running" \
    "ttyd" \
    pgrep -a ttyd

check_absent "openvscode-server is NOT running" \
    "openvscode" \
    pgrep -a openvscode-server

check "Backdoor cron job has been removed" \
    bash -c "! test -f /etc/cron.d/logicorp"

echo ""

# ------------------------------------------------------
# Access control checks
# Root login and password auth must be disabled in SSH.
# Anonymous FTP must be disabled.
# ------------------------------------------------------
echo "--- Access Control ---"

check "Root SSH login is disabled" \
    grep -q "^PermitRootLogin no" "$SSH_CONFIG"

check "Password authentication is disabled (key-only)" \
    grep -q "^PasswordAuthentication no" "$SSH_CONFIG"

check "Anonymous FTP login is disabled" \
    grep -q "^anonymous_enable=NO" "$FTP_CONFIG"

check "SSL is enabled on the FTP server" \
    grep -q "^ssl_enable=YES" "$FTP_CONFIG"

echo ""

# ------------------------------------------------------
# Network configuration checks
# IP forwarding must be on so VPN clients can reach
# internal networks through the gateway.
# ------------------------------------------------------
echo "--- Network Configuration ---"

check "IP forwarding is enabled" \
    bash -c "sysctl net.ipv4.ip_forward 2>/dev/null | grep -q '= 1'"

check "VPN interface $WG_IFACE has correct address" \
    bash -c "ip addr show $WG_IFACE 2>/dev/null | grep -q '10.8.0.1'"

check "Startup script no longer flushes firewall rules at boot" \
    bash -c "! grep -q '^nft flush ruleset' $STARTUP_SCRIPT"

check "Startup script loads firewall rules at boot" \
    grep -q "nft -f $NFT_CONFIG" "$STARTUP_SCRIPT"

echo ""

# ------------------------------------------------------
# Final score
# ------------------------------------------------------
TOTAL=$((PASS + FAIL))
echo "======================================================"
echo " RESULT: $PASS/$TOTAL checks passed"
if [ "$FAIL" -gt 0 ]; then
    echo " $FAIL check(s) failed. Review the [FAIL] lines above."
    exit 1
else
    echo " All checks passed."
fi
echo "======================================================"
