#!/bin/bash
# clean.sh - System hardening for LogiCorp Gateway
# See README.md for usage instructions and rollback procedures.

set -euo pipefail

# Load network and path configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Step 1: remove the backdoor cron job found during the audit
echo "[1/5] Removing backdoor cron job..."
rm -f /etc/cron.d/logicorp
service cron reload 2>/dev/null || true

# Step 2: stop web-exposed services that have no business reason to run
echo "[2/5] Stopping unnecessary services..."
pkill ttyd 2>/dev/null || true
pkill openvscode-server 2>/dev/null || true

# Step 3: harden SSH - disable root login and password authentication
echo "[3/5] Hardening SSH..."
cp "$SSH_CONFIG" "$SSH_CONFIG.backup"

# grep before sed handles any existing format (yes/no/commented out)
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

# Verify the changes actually took effect before moving on
grep -q "^PermitRootLogin no" "$SSH_CONFIG" \
    || { echo "ERROR: PermitRootLogin not set correctly"; exit 1; }
grep -q "^PasswordAuthentication no" "$SSH_CONFIG" \
    || { echo "ERROR: PasswordAuthentication not set correctly"; exit 1; }

# Step 4: disable anonymous FTP and add SSL (temporary fix, SFTP migration is the final solution)
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

# Append SSL options only if they are not already present
grep -q "rsa_cert_file" "$FTP_CONFIG" \
    || echo "rsa_cert_file=$CERT_PEM" >> "$FTP_CONFIG"
grep -q "rsa_private_key_file" "$FTP_CONFIG" \
    || echo "rsa_private_key_file=$CERT_KEY" >> "$FTP_CONFIG"
grep -q "force_local_data_ssl" "$FTP_CONFIG" \
    || echo "force_local_data_ssl=YES" >> "$FTP_CONFIG"
grep -q "force_local_logins_ssl" "$FTP_CONFIG" \
    || echo "force_local_logins_ssl=YES" >> "$FTP_CONFIG"

service vsftpd restart

# Step 5: stop run.sh from wiping firewall rules at every reboot
echo "[5/5] Fixing startup script..."
cp "$STARTUP_SCRIPT" "$STARTUP_SCRIPT.backup"
sed -i 's|nft flush ruleset|# nft flush ruleset - disabled by clean.sh|' "$STARTUP_SCRIPT"
grep -q "nft -f $NFT_CONFIG" "$STARTUP_SCRIPT" \
    || echo "nft -f $NFT_CONFIG" >> "$STARTUP_SCRIPT"

echo "Done. Run vpn_setup.sh next."
