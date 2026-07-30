#!/bin/bash
# firewall.sh - Firewall configuration for LogiCorp Gateway
# See README.md for usage instructions, verification steps, and rollback.

set -euo pipefail

# Load network and path configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

command -v nft >/dev/null \
    || { echo "ERROR: nft not found. Install nftables first."; exit 1; }

# Before locking SSH behind the firewall, make sure the VPN is actually up.
# If wg0 is not running here, IT will lose remote access once the rules are applied.
wg show "$WG_IFACE" >/dev/null 2>&1 \
    || { echo "ERROR: $WG_IFACE is not running. Run vpn_setup.sh and verify VPN access first."; exit 1; }

# Arm the panic button: if access is lost, rules clear automatically after the delay
echo "Arming panic button (firewall will be cleared in $PANIC_DELAY minutes)..."
echo "nft flush ruleset" | at now + "$PANIC_DELAY" minutes 2>/dev/null
AT_JOB=$(atq | tail -1 | awk '{print $1}')
echo "Cancel with: atrm $AT_JOB"
echo ""

# Write the full ruleset to a file so it survives reboots (run.sh loads it at boot)
echo "Writing nftables configuration..."
cat > "$NFT_CONFIG" << EOF
#!/usr/sbin/nft -f

flush ruleset

table inet filter {

    chain input {
        type filter hook input priority 0; policy drop;

        # let through replies to connections we started
        ct state established,related accept
        icmp type echo-request accept

        # WireGuard is the only open door from the internet
        udp dport $VPN_PORT accept comment "WireGuard VPN"

        # SSH and FTP are only reachable once you are inside the VPN tunnel
        ip saddr $VPN_SUBNET tcp dport $SSH_PORT accept comment "SSH via VPN only"
        ip saddr $VPN_SUBNET tcp dport $FTP_PORT accept comment "FTP via VPN - Finance access"
    }

    chain forward {
        type filter hook forward priority 0; policy drop;

        # let through replies for connections already allowed
        ct state established,related accept

        # internal machines can reach the database on MySQL port
        ip saddr $LAN_SUBNET ip daddr $DB_SUBNET tcp dport $DB_PORT accept comment "LAN to DB"

        # IT admins connected via VPN can SSH into internal machines and reach the database
        ip saddr $VPN_SUBNET ip daddr $LAN_SUBNET tcp dport $SSH_PORT accept comment "VPN to LAN SSH"
        ip saddr $VPN_SUBNET ip daddr $DB_SUBNET  tcp dport $DB_PORT accept comment "VPN to DB"

        # guest devices can browse the internet but nothing else
        ip saddr $GUEST_SUBNET tcp dport { 80, 443 } accept comment "Guest internet only"

        # these two are explicit so the intent is visible, not just a side effect of the default drop
        ip saddr $GUEST_SUBNET ip daddr $LAN_SUBNET drop comment "Guest blocked from LAN"
        ip saddr $GUEST_SUBNET ip daddr $DB_SUBNET  drop comment "Guest blocked from DB"
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}

# Without masquerade, machines in LAN and DB would try to reply directly to 10.8.0.x
# addresses and fail because they have no route to the VPN subnet.
# Masquerade rewrites the source IP to the gateway's address so replies come back correctly.
table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;
        ip saddr $VPN_SUBNET masquerade comment "Masquerade VPN traffic to internal networks"
    }
}
EOF

echo "Applying rules..."
nft -f "$NFT_CONFIG"

# double-check the policy actually landed
nft list ruleset | grep -q "policy drop" \
    || { echo "ERROR: rules did not apply correctly."; exit 1; }

echo ""
echo "Done. Verify access, then cancel the panic button: atrm $AT_JOB"
