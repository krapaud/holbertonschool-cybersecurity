#!/bin/bash
# vpn_setup.sh - WireGuard VPN deployment for LogiCorp Gateway
# See README.md for usage instructions and how to add users.

set -euo pipefail

# Load network and path configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Step 1: install WireGuard tools (the kernel module is already built in, no compilation needed)
echo "[1/4] Installing WireGuard tools..."
apt-get install -y wireguard-tools 2>/dev/null \
    || apk add wireguard-tools 2>/dev/null \
    || { echo "ERROR: could not install wireguard-tools. Install it manually and re-run."; exit 1; }

# Confirm the install actually worked before going further
command -v wg >/dev/null \
    || { echo "ERROR: wg command not found after install."; exit 1; }

# Step 2: generate the server key pair. The private key stays on the server, the public key goes to clients.
echo "[2/4] Generating server key pair..."
mkdir -p "$WG_DIR"
chmod 700 "$WG_DIR"

if [ ! -f "$WG_DIR/server_private.key" ]; then
    wg genkey | tee "$WG_DIR/server_private.key" | wg pubkey > "$WG_DIR/server_public.key"
    chmod 600 "$WG_DIR/server_private.key"
fi

SERVER_PRIVATE_KEY=$(cat "$WG_DIR/server_private.key")
SERVER_PUBLIC_KEY=$(cat "$WG_DIR/server_public.key")

# Catch the case where key generation silently produced an empty file
[ -n "$SERVER_PRIVATE_KEY" ] || { echo "ERROR: server private key is empty."; exit 1; }
[ -n "$SERVER_PUBLIC_KEY" ]  || { echo "ERROR: server public key is empty."; exit 1; }

# Step 3: write the server config with placeholder peer blocks for each user role
echo "[3/4] Writing server configuration..."
cat > "$WG_DIR/$WG_IFACE.conf" << EOF
[Interface]
Address = $VPN_SERVER_IP
ListenPort = $VPN_PORT
PrivateKey = $SERVER_PRIVATE_KEY

# Admin 1 - full internal access (10.8.0.2)
# [Peer]
# PublicKey = <admin1_public_key>
# AllowedIPs = 10.8.0.2/32

# Finance User 1 - FTP/SFTP access only (10.8.0.3)
# [Peer]
# PublicKey = <finance1_public_key>
# AllowedIPs = 10.8.0.3/32

# Finance User 2 - FTP/SFTP access only (10.8.0.4)
# [Peer]
# PublicKey = <finance2_public_key>
# AllowedIPs = 10.8.0.4/32
EOF
chmod 600 "$WG_DIR/$WG_IFACE.conf"

# Save a client config template so users know what to put on their side
cat > "$WG_DIR/client_template.conf" << EOF
[Interface]
Address = 10.8.0.X/24
PrivateKey = <client_private_key>

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = <gateway_public_ip>:$VPN_PORT
AllowedIPs = $DMZ_SUBNET
PersistentKeepalive = 25
EOF

# Step 4: enable IP forwarding so VPN clients can reach networks beyond the gateway
echo "[4/4] Enabling IP forwarding and starting WireGuard..."
sysctl -w net.ipv4.ip_forward=1
grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf \
    || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

wg-quick up "$WG_IFACE"
systemctl enable "wg-quick@$WG_IFACE" 2>/dev/null || true

# Confirm the interface came up before handing over to the next script
wg show "$WG_IFACE" >/dev/null \
    || { echo "ERROR: $WG_IFACE interface is not up."; exit 1; }

echo ""
echo "Server public key: $SERVER_PUBLIC_KEY"
echo "Done. Verify VPN access (ping 10.8.0.1), then run firewall.sh."
