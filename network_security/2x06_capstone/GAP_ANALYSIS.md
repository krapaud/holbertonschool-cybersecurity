# GAP ANALYSIS : LogiCorp Security Overhaul

**Client:** LogiCorp

**Consultant:** IronShield Consulting

**Date:** 2026-07-27

**Status:** Phase 1 - Pre-audit (based on documentation only)

---

## 1. Executive Summary

<!-- 3-4 sentences: why LogiCorp is vulnerable and what this engagement aims to fix -->

---

## 2. Gap Analysis

### 2.1 Network Segmentation

| Item | Current State | Target State | Gap | Risk Level |
| --- | --- | --- | --- | --- |
| Network architecture | Single flat subnet (192.168.1.x), all devices share the same network. | Three isolated networks: WAN, LAN, and DMZ. | Network has not been segmented yet. | Critical |
| Database isolation | Database sits on the same switch as all other devices, no isolation. | Database placed in its own isolated segment. | Any device on the network can reach the database directly. | Critical |
| Guest WiFi network | Guest WiFi is on the same switch as internal devices, no isolation. | Guest WiFi placed in its own isolated segment. | Guests can potentially reach internal systems. | Critical |

### 2.2 Remote Access (SSH)

| Item | Current State | Target State | Gap | Risk Level |
| --- | --- | --- | --- | --- |
| SSH exposure | SSH is open to the entire internet, no VPN is in place. | SSH only accessible through VPN, not exposed publicly. | No VPN exists, anyone on the internet can attempt to connect. | Critical |
| Root authentication | Root login is enabled, anyone with valid credentials can connect as root. | Root login disabled, users authenticate with personal accounts and use sudo. | Root login is still active, no sudo policy is in place. | Critical |
| Access control | No IP restriction is in place, any internet user can attempt to connect. | SSH access limited to VPN users only. | No access control or IP filtering is configured. | Critical |

### 2.3 Legacy FTP (Finance)

| Item | Current State | Target State | Gap | Risk Level |
| --- | --- | --- | --- | --- |
| Data encryption | FTP sends all data in cleartext, nothing is encrypted. | All file transfers go through SFTP, data is encrypted in transit. | FTP is still in use, SFTP has not been deployed. | Critical |
| Authentication | FTP sends credentials in cleartext over the network. | Credentials protected by SSH-based authentication via SFTP. | No secure authentication is in place. | Critical |
| Network exposure | FTP server is accessible from the entire internal network, no restriction in place. | FTP server accessible only to Finance team members. | No restriction in place, FTP server is reachable by all users on the network. | Critical |

### 2.4 Firewall

| Item | Current State | Target State | Gap | Risk Level |
| --- | --- | --- | --- | --- |
| Default policy | No firewall configured, all traffic is allowed by default. | Default deny policy, only explicitly allowed traffic passes. | No firewall or deny policy is in place, needs to be configured from scratch. | Critical |
| Active rules | No rules exist, all traffic flows freely. | Rules in place to allow only VPN traffic, SSH via VPN, and block everything else including direct FTP access. | No rules exist, needs to be built from scratch. | Critical |

---

## 3. Business Constraints

- **Finance team works remotely:** Remote access must remain available, VPN solution must support external connections from home.
- **FTP dependency:** FTP is actively used by the Finance team for data transfers, it cannot be removed without first migrating to SFTP.
- **Limited budget:** Budget is limited, solutions must prioritize open-source tools such as WireGuard, nftables, and SFTP over expensive commercial alternatives.

---

## 4. Requirement Conflicts

<!-- List where business needs conflict with security best practices -->

---

## 5. Open Questions

<!-- What is still unknown and must be verified on-site -->

---

## 6. Preliminary Recommendations

<!-- First solution ideas BEFORE accessing the lab -->
