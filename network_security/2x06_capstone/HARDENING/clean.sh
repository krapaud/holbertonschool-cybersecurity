#!/bin/bash
# clean.sh - System hardening for LogiCorp Gateway
# See README.md for usage instructions and rollback procedures.

set -euo pipefail

# Load network and path configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Step 1: remove the backdoor cron job we found in the audit
echo "[1/5] Removing backdoor cron job..."
rm -f /etc/cron.d/logicorp
service cron reload 2>/dev/null || true

# Step 2: stop the two web services that were running without any documented reason
echo "[2/5] Stopping unnecessary services..."
pkill ttyd 2>/dev/null || true
pkill openvscode-server 2>/dev/null || true

# Step 3: lock down SSH so only key-based login works, and root can no longer log in directly
echo "[3/5] Hardening SSH..."
cp "$SSH_CONFIG" "$SSH_CONFIG.backup"

# check the current format before rewriting to handle any variation (commented, yes, no)
if grep -q "^PermitRootLogin" "$SSH_CONFIG"; then
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' "$SSH_CONFIG"
else
    echo "PermitRootLogin no" >> "$SSH_CONFIG"
fi

if grep -q "^PasswordAuthentication" "$SSH_CONFIG"; then
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$SSH_CONFIG"
else
    echo "PasswordAuthentication no" >> "$SSH_CONFIG"
fi

service ssh restart

# make sure the restart actually picked up the new config before continuing
grep -q "^PermitRootLogin no" "$SSH_CONFIG" \
    || { echo "ERROR: PermitRootLogin not set correctly"; exit 1; }
grep -q "^PasswordAuthentication no" "$SSH_CONFIG" \
    || { echo "ERROR: PasswordAuthentication not set correctly"; exit 1; }

# Step 4: secure FTP without breaking it for Finance
# We disable anonymous access and make SSL available, but we do NOT force it yet.
# Forcing SSL now would break the Finance team's existing FTP clients immediately.
# Once they have confirmed their clients support FTPS, force_local_logins_ssl=YES
# and force_local_data_ssl=YES can be added manually as a follow-up step.
echo "[4/5] Hardening FTP..."
openssl req -x509 -nodes -days "$CERT_DAYS" -newkey rsa:2048 \
    -keyout "$CERT_KEY" \
    -out "$CERT_PEM" \
    -subj "/CN=$CERT_CN" 2>/dev/null
cp "$FTP_CONFIG" "$FTP_CONFIG.backup"

if grep -q "^anonymous_enable" "$FTP_CONFIG"; then
    sed -i 's/^anonymous_enable.*/anonymous_enable=NO/' "$FTP_CONFIG"
else
    echo "anonymous_enable=NO" >> "$FTP_CONFIG"
fi

if grep -q "^ssl_enable" "$FTP_CONFIG"; then
    sed -i 's/^ssl_enable.*/ssl_enable=YES/' "$FTP_CONFIG"
else
    echo "ssl_enable=YES" >> "$FTP_CONFIG"
fi

# add the certificate paths so vsftpd knows where to find them
grep -q "rsa_cert_file" "$FTP_CONFIG" \
    || echo "rsa_cert_file=$CERT_PEM" >> "$FTP_CONFIG"
grep -q "rsa_private_key_file" "$FTP_CONFIG" \
    || echo "rsa_private_key_file=$CERT_KEY" >> "$FTP_CONFIG"

service vsftpd restart

# Step 5: stop the startup script from wiping firewall rules every time the machine reboots
echo "[5/5] Fixing startup script..."
cp "$STARTUP_SCRIPT" "$STARTUP_SCRIPT.backup"
sed -i 's|nft flush ruleset|# nft flush ruleset (disabled by clean.sh)|' "$STARTUP_SCRIPT"
grep -q "nft -f $NFT_CONFIG" "$STARTUP_SCRIPT" \
    || echo "nft -f $NFT_CONFIG" >> "$STARTUP_SCRIPT"

echo "Done. Run vpn_setup.sh next."
