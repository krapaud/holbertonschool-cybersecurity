# AUDIT REPORT : LogiCorp Gateway

**Client:** LogiCorp

**Consultant:** IronShield Consulting

**Date:** 2026-07-28

**Status:** Phase 2 - Live Audit

---

## 1. System Information

| Parameter | Value |
| --- | --- |
| Hostname | 8602d15dcce94e8f87817344e12e8477-2377118072 |
| OS / Kernel | Linux 6.1.176 x86_64 |
| Uptime | ~3 minutes at time of audit |
| Init system | Not systemd (container environment) |

---

## 2. Network Topology

| Interface | IP Address | Notes |
| --- | --- | --- |
| lo | 127.0.0.1/8 | Loopback |
| eth0 | 169.254.172.2/22 | Management interface |
| eth1 | 10.42.148.94/16 | Main network interface |

**Default route:** 10.42.0.1 via eth1

**ARP table:** 10.42.0.1 (gateway only)

**Discrepancy:** Documentation references a 192.168.1.x flat network. Live system uses 10.42.0.0/16. No WireGuard interface present, confirming VPN is not deployed.

---

## 3. Attack Surface

### Open TCP Ports

| Port | Service | Process | Notes |
| --- | --- | --- | --- |
| 21 | FTP | vsftpd (root) | Cleartext protocol, exposed on all interfaces |
| 22 | SSH | sshd (root) | Exposed on all interfaces, no VPN protection |
| 3000 | Web terminal | ttyd (root) | Undocumented, provides root shell via browser |
| 3001 | VS Code server | openvscode-server (root) | Undocumented, full IDE access via browser |

### Open UDP Ports

| Port | Service | Notes |
| --- | --- | --- |
| None | - | No UDP services detected |

---

## 4. Security Controls

| Control | Status | Notes |
| --- | --- | --- |
| Firewall (nftables) | | To be verified |
| SELinux / AppArmor | | To be verified |

---

## 5. User Accounts

| User | Shell | Sudo | Notes |
| --- | --- | --- | --- |
| | | | To be verified |

**SSH authorized keys:** To be verified

---

## 6. Running Services

| Service | PID | User | Notes |
| --- | --- | --- | --- |
| vsftpd | 63 | root | FTP server |
| sshd | 89 | root | SSH server |
| cron | 78 | root | Scheduler |
| ttyd | 91 | root | Web terminal on port 3000, undocumented |
| openvscode-server | 96/105/116 | root | VS Code server on port 3001, undocumented |

---

## 7. Scheduled Tasks

| Schedule | User | Command | Risk |
| --- | --- | --- | --- |
| Every minute | root | `/usr/bin/curl http://192.168.1.200/ping` | Critical - backdoor beacon |

---

## 8. Discrepancies

| Item | Documentation | Reality | Risk |
| --- | --- | --- | --- |
| Port 3000 | Not mentioned | ttyd web terminal running as root | Critical |
| Port 3001 | Not mentioned | OpenVSCode server running as root | Critical |
| Cron job | Not mentioned | Backdoor beacon to 192.168.1.200 | Critical |
| Network range | 192.168.1.x | 10.42.0.0/16 | Informational |

---

## 9. Critical Findings

| Finding | Severity | Description |
| --- | --- | --- |
| Backdoor cron job | Critical | Root cron job beacons to 192.168.1.200 every minute (`FLAG{CR0N_B4CKD00R}`) |
| Undocumented web terminal | Critical | ttyd on port 3000 gives root shell access via browser |
| Undocumented VS Code server | Critical | openvscode-server on port 3001 gives full IDE access as root |
| SSH exposed publicly | Critical | SSH port 22 open on all interfaces, no VPN, no IP filtering |
| FTP in cleartext | Critical | vsftpd transmits credentials and data unencrypted |
