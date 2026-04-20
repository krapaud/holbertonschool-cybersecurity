# Hardening Automation

A modular Linux hardening framework implementing STIG-2024 security policies.

## Architecture

```text
1x05_hardening/
├── harden.sh           # Entry point
├── config/
│   └── harden.cfg      # Configuration variables
└── lib/
    ├── network.sh      # Network hardening
    ├── ssh.sh          # SSH hardening
    ├── identity.sh     # User and password hardening
    └── system.sh       # System hardening
```

## Usage

```bash
sudo /path/to/harden.sh
```

The script must be run as root. All actions are logged to `/var/log/hardening.log`.

## Rules Implemented

### Network (lib/network.sh)

- N-01: Firewall policy file with default deny incoming / allow outgoing
- N-02: Allow only SSH, HTTP (80), HTTPS (443)
- N-03: Disable IP forwarding and ICMP echo requests

### SSH (lib/ssh.sh)

- S-01: Disable password authentication, enable public key authentication
- S-02: Disable root login

### Identity (lib/identity.sh)

- I-01: Password policy (min length 12, complexity, max age 90 days)
- I-02: Account lockout after 5 failed login attempts
- I-03: Delete users with UID > 1000 not in sudo/wheel groups
- I-04: Lock root password

### System (lib/system.sh)

- H-01: Update and upgrade packages non-interactively
- H-02: Remove bloatware (telnet, ftp, netcat-traditional)
- H-03: Install security tools (auditd, fail2ban)

## Configuration

All variables are defined in `config/harden.cfg`:

| Variable | Description | Default |
| --- | --- | --- |
| SSH_PORT | SSH port | 22 |
| ALLOWED_SSH_USERS | Allowed SSH users | root |
| ALLOW_HTTP | HTTP port | 80 |
| ALLOW_HTTPS | HTTPS port | 443 |
| PASS_MAX_DAYS | Password max age | 90 |
| PASS_MIN_LEN | Password min length | 12 |
| FAIL_LOCK_ATTEMPTS | Failed login attempts before lockout | 5 |
