#!/bin/bash
# firewall.sh - Firewall configuration for LogiCorp Gateway
# See README.md for usage instructions, verification steps, and rollback.

set -euo pipefail

# Load network and path configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Confirm nft is available before doing anything
command -v nft >/dev/null \
    || { echo "ERROR: nft not found. Install nftables first."; exit 1; }

# Arm the panic button: if access is lost, rules clear automatically after the delay
echo "Arming panic button (firewall will be cleared in 5 minutes)..."
echo "nft flush ruleset" | at now + "$PANIC_DELAY" minutes 2>/dev/null
AT_JOB=$(atq | tail -1 | awk '{print $1}')
echo "Cancel with: atrm $AT_JOB"
echo ""

# Write the full ruleset to a file so it can be reloaded at boot by run.sh
echo "Writing nftables configuration..."
cat > "$NFT_CONFIG" << EOF
#!/usr/sbin/nft -f

flush ruleset

table inet filter {

    chain input {
        type filter hook input priority 0; policy drop;

        # Allow responses to connections the gateway initiated
        ct state established,related accept
        icmp type echo-request accept

        # VPN is the only entry point from the internet
        udp dport $VPN_PORT accept comment "WireGuard VPN"

        # SSH and FTP are only reachable through the VPN tunnel
        ip saddr $VPN_SUBNET tcp dport $SSH_PORT accept comment "SSH via VPN only"
        ip saddr $VPN_SUBNET tcp dport $FTP_PORT accept comment "FTP via VPN - temporary"
    }

    chain forward {
        type filter hook forward priority 0; policy drop;

        # Allow return traffic for already-permitted connections
        ct state established,related accept

        # Each rule below matches the zone access matrix in FIREWALL_POLICY.md
        ip saddr $LAN_SUBNET ip daddr $DB_SUBNET tcp dport $DB_PORT accept comment "LAN to DB"
        ip saddr $VPN_SUBNET ip daddr $LAN_SUBNET tcp dport $SSH_PORT accept comment "VPN to LAN SSH"
        ip saddr $VPN_SUBNET ip daddr $DB_SUBNET  tcp dport $DB_PORT accept comment "VPN to DB"
        ip saddr $GUEST_SUBNET tcp dport { 80, 443 }                  accept comment "Guest internet only"

        # Explicit guest isolation: stated clearly rather than relying on the default drop
        ip saddr $GUEST_SUBNET ip daddr $LAN_SUBNET drop comment "Guest blocked from LAN"
        ip saddr $GUEST_SUBNET ip daddr $DB_SUBNET  drop comment "Guest blocked from DB"
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF

echo "Applying rules..."
nft -f "$NFT_CONFIG"

# Confirm the policy was actually applied and not silently ignored
nft list ruleset | grep -q "policy drop" \
    || { echo "ERROR: rules did not apply correctly."; exit 1; }

echo ""
echo "Done. Verify access, then cancel the panic button: atrm $AT_JOB"
