# 2x06 Capstone : IronShield Consulting for LogiCorp

## Context

This project simulates a real consulting engagement. IronShield Consulting was hired by LogiCorp after the company was hit by a ransomware attack. The root cause was a flat network where a guest WiFi device could reach the database directly. The mission is to audit the current infrastructure, identify all vulnerabilities, and design a Zero Trust architecture to prevent this from happening again.

The project is split into 6 phases. Each phase produces a document that feeds into the next one.

---

## Phases and Documents

| Phase | Document | Description |
| --- | --- | --- |
| 1 - Discovery | `GAP_ANALYSIS.md` | Current state vs target state for each security area |
| 2 - Assessment | `AUDIT_REPORT.md` | Live audit of the machine : commands, outputs, findings |
| 3 - Blueprint | `DESIGN_PACKAGE/` | Architecture, firewall rules, VPN design, implementation plan |
| 4 - Implementation | `HARDENING/` | Scripts that apply the hardening changes |
| 5 - Validation | `VALIDATION/` | Scripts that verify the hardening worked |
| 6 - Handoff | `DEFENSE.md` | Justification of every technical choice |

---

## How the Documents Are Structured

Each document in this project follows the same logic : the bullet points in the project instructions become the section headings (`##`). For example, the instructions say "Specific rules with justification" so FIREWALL_POLICY.md has a section called "Firewall Rules" with a justification column in every table.

Every DESIGN_PACKAGE document starts with a **Sources** section. This section explains where each piece of information in the document comes from, so the reader understands the reasoning instead of just seeing the result:

- **GAP_ANALYSIS.md** is the source for the target architecture, the zones, and the business constraints.
- **AUDIT_REPORT.md** is the source for the current state of the machine and what needs to be fixed.
- **Official documentation** (nftables wiki, WireGuard docs) is the source for syntax, default ports, and configuration file formats.

The document style (headers, tables, notes under each rule) follows the same format as GAP_ANALYSIS.md and AUDIT_REPORT.md to keep the whole project consistent.

---

## DESIGN_PACKAGE Contents

| File | Description |
| --- | --- |
| `DESIGN_TOPOLOGY.png` | Network diagram showing current flat network and target segmented architecture |
| `FIREWALL_POLICY.md` | nftables rules for each zone, with default deny policy and justification for every rule |
| `VPN_DESIGN.md` | WireGuard hub-and-spoke topology, IP addressing, access control per role |
| `IMPLEMENTATION_PLAN.md` | Step-by-step deployment order designed to avoid locking out the admin |

---

## HARDENING Contents

| File | Description |
| --- | --- |
| `config.sh` | All IPs, ports, and file paths in one place. Every script sources this file. Values can be overridden with environment variables without editing the file. |
| `clean.sh` | Removes the backdoor cron, stops unnecessary services, hardens SSH (key-only, no root login), enables FTPS, and fixes the startup script. |
| `vpn_setup.sh` | Installs WireGuard, generates the server key pair, creates the wg0 interface, enables IP forwarding. Must run before firewall.sh. |
| `firewall.sh` | Applies nftables rules with default deny policy and NAT masquerade. Includes a panic button that automatically clears the rules after a few minutes if access is lost. |

Run order: `clean.sh` then `vpn_setup.sh` then `firewall.sh`. See `HARDENING/README.md` for full usage instructions.

---

## VALIDATION Contents

| File | Description |
| --- | --- |
| `tests.sh` | Runs 18 automated checks across firewall, services, access control, and network configuration. Prints `[PASS]` or `[FAIL]` for each check and exits with code 1 if anything fails. |

See `VALIDATION/README.md` for a full explanation of how the script works.

---

## Flags Found During Audit

| Flag | Location | Finding |
| --- | --- | --- |
| FLAG{AUD1T_FL4T_N3TW0RK} | `/etc/logicorp/network.conf` | Network explicitly set to FLAT |
| FLAG{CL34RT3XT_FTP} | `/etc/vsftpd.conf` | FTP with no encryption, anonymous access enabled |
| FLAG{UNN3C3SS4RY_S3RV1C3} | `/etc/logicorp/telnet.flag` | ttyd and openvscode-server running as root, undocumented |
| FLAG{R00T_SSH_1S_D4NG3R} | `/etc/ssh/sshd_config` | Root login and password auth enabled, SSH open to internet |
| FLAG{CR0N_B4CKD00R} | `/etc/cron.d/logicorp` | Hidden cron job contacting external server every minute |
| FLAG{S3NS1T1V3_B4CKUP_EXP0S3D} | `/opt/logicorp/backups/backup.sql` | Database backup readable by anyone, plain text password inside |
| FLAG{1DS_D3T3CT10N_W0RKS} | `/var/log/suricata/fast.log` | IDS log can be written to by the startup script |
| FLAG{Z3R0_TRU5T_Z0N3S} | `/etc/logicorp/db.conf` | Database on the same flat network as everything else |
| FLAG{R00T_L0G1N_D3T3CT3D} | `/etc/logicorp/security.policy` | Root login policy documented but not enforced |
| FLAG{SSH_BRUTE_BLOCKED} | `/etc/fail2ban/action.d/logicorp-flag.conf` | fail2ban configured but not running, triggers on SSH brute force ban |
