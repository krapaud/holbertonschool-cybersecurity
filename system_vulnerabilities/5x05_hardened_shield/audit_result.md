# Hardened Shield Security Audit

- Date: 2026-11-27 10:05:51 UTC
- Overall status: **FAIL**
- Score: **42%** (23/55)

## Category scores

- Kernel hardening: **45%** (10/22)
- Filesystem security: **29%** (2/7)
- Identity security: **50%** (7/14)
- Service security: **20%** (1/5)
- Container security: **43%** (3/7)

## Check details

### Kernel hardening: 45% (10/22)

- [FAIL] IPv4 forwarding disabled: 1
- [PASS] IPv4 redirects disabled: 0
- [FAIL] Default IPv4 redirects disabled: 1
- [FAIL] IPv4 redirect sending disabled: 1
- [FAIL] Default IPv4 redirect sending disabled: 1
- [FAIL] IPv4 reverse path filtering enabled: 0
- [FAIL] Default IPv4 reverse path filtering enabled: 0
- [PASS] TCP SYN cookies enabled: 1
- [PASS] IPv4 source routing disabled: 0
- [FAIL] Default IPv4 source routing disabled: 1
- [PASS] ICMP broadcasts ignored: 1
- [FAIL] Martian packets logged: 0
- [FAIL] Default martian packets logged: 0
- [FAIL] IPv6 redirects disabled: 1
- [FAIL] Default IPv6 redirects disabled: 1
- [PASS] IPv6 source routing disabled: 0
- [PASS] Default IPv6 source routing disabled: 0
- [PASS] IPv6 forwarding disabled: 0
- [PASS] Address space randomization enabled: 2
- [FAIL] Kernel pointers restricted: 0
- [PASS] Kernel log access restricted: 1
- [PASS] SUID core dumps disabled: 0

### Filesystem security: 29% (2/7)

- [PASS] Safe permissions on /tmp: 1777
- [FAIL] noexec,nosuid,nodev options on /tmp: rw
- [PASS] Safe permissions on /var/tmp: 1777
- [FAIL] noexec,nosuid,nodev options on /var/tmp: rw
- [FAIL] Private access to /etc/shadow: 0640
- [FAIL] Private access to /etc/gshadow: 0640
- [FAIL] SUID/SGID inventory exists: not generated

### Identity security: 50% (7/14)

- [PASS] pam_pwquality enabled: common-password
- [FAIL] Password policy minlen: missing
- [FAIL] Password policy dcredit: missing
- [FAIL] Password policy ucredit: missing
- [FAIL] Password policy lcredit: missing
- [FAIL] Password policy ocredit: missing
- [FAIL] Five password history: PAM
- [FAIL] Lockout after five failures: faillock.conf
- [PASS] SSH PermitRootLogin: no
- [PASS] SSH PasswordAuthentication: no
- [PASS] SSH PubkeyAuthentication: yes
- [PASS] SSH AllowUsers: shieldadmin
- [PASS] sshd_config syntax: configuration valid
- [PASS] Root password locked: passwd -S

### Service security: 20% (1/5)

- [FAIL] Nginx active: process absent
- [FAIL] SSH active: process absent
- [FAIL] Fail2ban active: process absent
- [FAIL] HTTP /health check: endpoint unavailable
- [PASS] Unused services stopped: no processes detected

### Container security: 43% (3/7)

- [PASS] Running in a container: Docker/OCI marker
- [FAIL] Non-root Nginx worker: no active worker
- [FAIL] No effective capabilities: 00000000a80425fb
- [FAIL] no-new-privileges enabled: 0
- [PASS] Seccomp filter enabled: 2
- [FAIL] Read-only root filesystem: rw
- [PASS] No secrets in Dockerfile: Dockerfile

## Conclusion

PASS requires every check to succeed. Capability, mount, and runtime
checks reflect the Docker options used at container launch, not only
the contents of the image.
