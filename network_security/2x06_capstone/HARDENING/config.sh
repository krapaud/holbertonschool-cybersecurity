#!/bin/bash
# config.sh - Network and path configuration for LogiCorp Gateway hardening
# Sourced by clean.sh, vpn_setup.sh and firewall.sh.
#
# All values can be overridden by environment variables without editing this file.
# Example: VPN_PORT=1194 bash firewall.sh

# Network zones (from FIREWALL_POLICY.md section 2)
VPN_SUBNET="${VPN_SUBNET:-10.8.0.0/24}"
VPN_SERVER_IP="${VPN_SERVER_IP:-10.8.0.1/24}"
DMZ_SUBNET="${DMZ_SUBNET:-10.0.1.0/24}"
LAN_SUBNET="${LAN_SUBNET:-10.0.2.0/24}"
DB_SUBNET="${DB_SUBNET:-10.0.3.0/24}"
GUEST_SUBNET="${GUEST_SUBNET:-10.0.4.0/24}"

# Service ports
VPN_PORT="${VPN_PORT:-51820}"
SSH_PORT="${SSH_PORT:-22}"
FTP_PORT="${FTP_PORT:-21}"
DB_PORT="${DB_PORT:-3306}"

# WireGuard
WG_IFACE="${WG_IFACE:-wg0}"
WG_DIR="${WG_DIR:-/etc/wireguard}"

# Config file paths
SSH_CONFIG="${SSH_CONFIG:-/etc/ssh/sshd_config}"
FTP_CONFIG="${FTP_CONFIG:-/etc/vsftpd.conf}"
NFT_CONFIG="${NFT_CONFIG:-/etc/nftables.conf}"
STARTUP_SCRIPT="${STARTUP_SCRIPT:-/etc/run.sh}"

# Firewall panic button delay in minutes
PANIC_DELAY="${PANIC_DELAY:-5}"

# SSL certificate settings for the FTP server
CERT_DAYS="${CERT_DAYS:-365}"
CERT_CN="${CERT_CN:-logicorp-gateway}"
CERT_KEY="${CERT_KEY:-/etc/ssl/private/vsftpd.key}"
CERT_PEM="${CERT_PEM:-/etc/ssl/certs/vsftpd.pem}"
