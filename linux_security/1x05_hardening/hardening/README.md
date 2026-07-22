# Hardening Automation

A modular Linux hardening framework implementing STIG-2024 security policies.

## Architecture

```text
hardening/
├── harden.sh           # Entry point : orchestrates all modules
├── config/
│   └── harden.cfg      # Centralized configuration variables
├── lib/
│   ├── ssh.sh          # SSH hardening (S-01, S-02)
│   ├── network.sh      # Network hardening (N-01, N-02, N-03)
│   ├── identity.sh     # User and password hardening (I-01 to I-04)
│   └── system.sh       # System package hardening (H-01 to H-03)
└── audit_report.txt    # Compliance report generated on each run

```text

## Usage

```bash
sudo ./harden.sh

```text

The script must be run as root. All actions are logged to `/var/log/hardening.log`. A compliance report is written to `audit_report.txt` at the end of each run.

## Rules Implemented

### SSH (`lib/ssh.sh`)

| Rule | Description |
| --- | --- |
| S-01 | Disable password authentication, enable public key authentication |
| S-02 | Disable direct root login via SSH |

### Network (`lib/network.sh`)

| Rule | Description |
| --- | --- |
| N-01 | Firewall policy file with default deny incoming / allow outgoing |
| N-02 | Allow only SSH (22), HTTP (80), HTTPS (443) |
| N-03 | Disable IP forwarding and ICMP echo requests via sysctl |

### Identity (`lib/identity.sh`)

| Rule | Description |
| --- | --- |
| I-01 | Password policy: min length 12, complexity (upper/lower/digit/special), max age 90 days |
| I-02 | Account lockout after 5 failed login attempts via pam_faillock |
| I-03 | Remove users with UID > 1000 not in sudo/wheel groups |
| I-04 | Lock root password to prevent direct login |

### System (`lib/system.sh`)

| Rule | Description |
| --- | --- |
| H-01 | Update and upgrade all packages non-interactively |
| H-02 | Remove insecure tools: telnet, ftp, netcat-traditional |
| H-03 | Install security tools: auditd, fail2ban |

## Configuration

All variables are defined in `config/harden.cfg`:

| Variable | Description | Default |
| --- | --- | --- |
| `SSH_PORT` | SSH listening port | `22` |
| `ALLOWED_SSH_USERS` | Allowed SSH users | `("root")` |
| `ALLOW_HTTP` | Allowed HTTP port | `80` |
| `ALLOW_HTTPS` | Allowed HTTPS port | `443` |
| `PASS_MAX_DAYS` | Password maximum age (days) | `90` |
| `PASS_MIN_LEN` | Password minimum length | `12` |
| `PASS_UCREDIT` | Min uppercase characters required | `-1` |
| `PASS_LCREDIT` | Min lowercase characters required | `-1` |
| `PASS_DCREDIT` | Min digits required | `-1` |
| `PASS_OCREDIT` | Min special characters required | `-1` |
| `FAIL_LOCK_ATTEMPTS` | Failed attempts before account lockout | `5` |

## Compliance Report

The `audit_report.txt` file uses three severity levels:

| Level | Meaning |
| --- | --- |
| `[INFO]` | Rule applied or already compliant |
| `[WARN]` | Non-critical notice (e.g. packages already up to date) |
| `[ERROR]` | Rule failed : sets overall `COMPLIANCE STATUS` to `FAIL` |

### Sample output

```text
===============================================
 HARDENING AUDIT REPORT - 2026-04-20 14:42:16
===============================================
[INFO] Hardening procedure completed successfully.
[INFO] SSH configured on port 22.
[INFO] Firewall policy created: ports 22, 80, 443 ALLOWED.
[INFO] No unauthorized users found.
[WARN] Package updates skipped (already up to date).
[INFO] Removed: telnet, ftp, netcat-traditional.
[INFO] Installed: auditd, fail2ban.
===============================================
 COMPLIANCE STATUS: PASS
===============================================

```text

A `COMPLIANCE STATUS: FAIL` is triggered if any module encounters an error (e.g. missing `sshd_config`, failed package install, or failed root password lock). All timestamped events are also written to `/var/log/hardening.log`.
