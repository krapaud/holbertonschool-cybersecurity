#!/bin/bash
# config.sh - Network and path configuration for LogiCorp Gateway hardening
# Sourced by clean.sh, vpn_setup.sh and firewall.sh.
# Change values here only - never edit IPs or paths directly in the scripts.

# Network zones (from FIREWALL_POLICY.md section 2)
VPN_SUBNET="10.8.0.0/24"
VPN_SERVER_IP="10.8.0.1/24"
DMZ_SUBNET="10.0.1.0/24"
LAN_SUBNET="10.0.2.0/24"
DB_SUBNET="10.0.3.0/24"
GUEST_SUBNET="10.0.4.0/24"

# Service ports
VPN_PORT="51820"
SSH_PORT="22"
FTP_PORT="21"
DB_PORT="3306"

# WireGuard
WG_IFACE="wg0"
WG_DIR="/etc/wireguard"

# Config file paths
SSH_CONFIG="/etc/ssh/sshd_config"
FTP_CONFIG="/etc/vsftpd.conf"
NFT_CONFIG="/etc/nftables.conf"
STARTUP_SCRIPT="/etc/run.sh"
