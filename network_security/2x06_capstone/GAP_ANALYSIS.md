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
| Network architecture | Flat Network, single subnet (192.168.1.x), all devices share the same broadcast domain. | 3 separate networks: WAN, LAN (internal), DMZ (public). | No segmentation implemented, needs to be split into 3 isolated networks. | Critical |
| Database isolation | Connected to the same switch as all other devices, no isolation | Isolated in a dedicated network segment | No isolation exists, direct access possible from any device | Critical |
| Guest WiFi network | Connected to the same switch as all other devices, no isolation | Isolated in a dedicated network segment | No isolation exists, direct access possible from any device | Critical |

### 2.2 Remote Access (SSH)

| Item | Current State | Target State | Gap | Risk Level |
| --- | --- | --- | --- | --- |
| SSH exposure | SSH exposed to the entire internet, no VPN, root login enabled. | SSH accessible only through VPN, root login disabled. | Root login not disabled, no sudo-based access control in place. | Critical |
| Root authentication | Root login is enabled, anyone with credentials can connect as root | Root login disabled, users must connect with personal accounts and escalate with sudo | No VPN exists, SSH is reachable directly from the internet. | Critical |
| Access control | No access control in place, any internet user can attempt to connect via SSH. | SSH access restricted to authorized personnel connected through VPN only | No IP restriction or access control mechanism exists. | Critical |

### 2.3 Legacy FTP (Finance)

| Item | Current State | Target State | Gap | Risk Level |
| --- | --- | --- | --- | --- |
| Data encryption | | | | |
| Authentication | | | | |
| Network exposure | | | | |

### 2.4 Firewall

| Item | Current State | Target State | Gap | Risk Level |
| --- | --- | --- | --- | --- |
| Default policy | | | | |
| Active rules | | | | |

---

## 3. Business Constraints

<!-- List the constraints that limit available solutions -->

---

## 4. Requirement Conflicts

<!-- List where business needs conflict with security best practices -->

---

## 5. Open Questions

<!-- What is still unknown and must be verified on-site -->

---

## 6. Preliminary Recommendations

<!-- First solution ideas BEFORE accessing the lab -->
