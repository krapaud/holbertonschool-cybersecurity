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

**Commands used:**

```bash
ss -tlnp
ss -ulnp
```

### Finding : FTP cleartext : FLAG{CL34RT3XT_FTP}

I checked the FTP server configuration to understand how it was set up:

```bash
cat /etc/vsftpd.conf
```

Two critical settings stood out:

```text
ssl_enable=NO
anonymous_enable=YES
```

FTP is running with no encryption and anonymous access enabled. Any traffic between the Finance team and the server is transmitted in cleartext, including usernames, passwords, and file contents. Any attacker on the same network can capture this data with Wireshark.

---

## 4. Security Controls

| Control | Status | Notes |
| --- | --- | --- |
| Firewall (nftables) | Disabled | `/etc/run.sh` explicitly runs `nft flush ruleset` at startup, all rules are cleared |
| SELinux / AppArmor | Cannot be verified | No systemd, container environment |

**How I found it:**

I read the startup script to understand what runs at boot:

```bash
cat /etc/run.sh
```

The script explicitly disables the firewall:

```bash
nft flush ruleset 2>/dev/null
```

This means the firewall is cleared every time the machine restarts. There is no persistent traffic filtering in place.

---

## 5. User Accounts

| User | Shell | Sudo | Notes |
| --- | --- | --- | --- |
| root | /bin/bash | Full | Not accessible remotely (direct login disabled) |
| student | /bin/bash | Unknown | Audit user, no sudo available |
| sync | /bin/sync | None | System user |

**Commands used:**

```bash
cat /etc/passwd | grep -v nologin | grep -v false
ls -la ~/.ssh/
cat ~/.ssh/authorized_keys
```

**SSH authorized keys:** Two ed25519 keys loaded for `mur.mickael@gmail.com`. Presence of two keys for the same identity should be investigated.

### Finding : SSH root login enabled : FLAG{R00T_SSH_1S_D4NG3R}

I read the SSH server configuration to check for dangerous settings:

```bash
cat /etc/ssh/sshd_config
```

Two critical misconfigurations appeared immediately:

```text
PermitRootLogin yes
PasswordAuthentication yes
```

At the bottom of the file, hidden in a comment next to "Legacy access - do not remove":

```text
# FLAG{R00T_SSH_1S_D4NG3R}
```

Direct root SSH access is enabled with password authentication. Combined with no VPN and no IP restriction, any attacker on the internet can brute-force root credentials. The comment "do not remove" is exactly the kind of social engineering an attacker uses to keep their backdoor in place.

### Finding : Predictable root password

Inside `/etc/run.sh`, the root password is set at every boot with this command:

```bash
echo root:`echo $HOSTNAME | cut -d '-' -f 1` | chpasswd
```

The hostname is `8602d15dcce94e8f87817344e12e8477-2377118072`. The command extracts everything before the first `-`, giving `8602d15dcce94e8f87817344e12e8477` as the root password. Anyone who can read the hostname can immediately derive the root credentials.

---

## 6. Running Services

| Service | PID | User | Notes |
| --- | --- | --- | --- |
| vsftpd | 63 | root | FTP server |
| sshd | 89 | root | SSH server |
| cron | 78 | root | Scheduler |
| ttyd | 91 | root | Web terminal on port 3000, undocumented |
| openvscode-server | 96/105/116 | root | VS Code server on port 3001, undocumented |

**Commands used:**

```bash
ps aux
```

---

## 7. Scheduled Tasks

| Schedule | User | Command | Risk |
| --- | --- | --- | --- |
| Every minute | root | `/usr/bin/curl http://192.168.1.200/ping` | Critical - backdoor beacon |

### Finding : Backdoor cron job : FLAG{CR0N_B4CKD00R}

While auditing running processes with `ps aux`, I noticed that root was executing a `curl` command every minute pointing to an internal address:

```text
root  173  0.0  0.0  2892  1032  ?  Ss  07:58  0:00  /bin/sh -c /usr/bin/curl http://192.168.1.200/ping
```

A root process making outbound HTTP requests every minute is a classic sign of a beacon. I checked the cron configuration:

```bash
cat /etc/cron.d/logicorp
```

Output:

```text
* * * * * root /usr/bin/curl http://192.168.1.200/ping
# FLAG{CR0N_B4CKD00R}
```

Someone planted a cron job that runs as root and phones home to an internal address every minute. This is a persistence mechanism likely left behind after the ransomware attack.

---

## 8. Sensitive Data Exposure

### Finding : World-readable database backup : FLAG{S3NS1T1V3_B4CKUP_EXP0S3D}

While listing directories in `/opt/`, I noticed a `logicorp` folder:

```bash
ls /opt/
ls -la /opt/logicorp/backups/
cat /opt/logicorp/backups/backup.sql
```

Output:

```text
root_password_backup=123456
FLAG{S3NS1T1V3_B4CKUP_EXP0S3D}
```

A database backup file is sitting in a world-readable directory with no access control. It contains a plaintext root password. Anyone who can SSH into the machine can read the entire backup and extract credentials.

### Finding : IDS log manipulation : FLAG{1DS_D3T3CT10N_W0RKS}

Inside `/etc/run.sh`, the startup script injects fake entries directly into the Suricata log:

```bash
echo "FLAG{1DS_D3T3CT10N_W0RKS}" >> /var/log/suricata/fast.log
```

Confirmed by reading the log:

```bash
cat /var/log/suricata/fast.log
```

An attacker with control over initialization scripts can inject fake entries into the IDS log, making detection unreliable and masking real attack activity.

---

## 9. Discrepancies

| Item | Documentation | Reality | Risk |
| --- | --- | --- | --- |
| Port 3000 | Not mentioned | ttyd web terminal running as root | Critical |
| Port 3001 | Not mentioned | OpenVSCode server running as root | Critical |
| Cron job | Not mentioned | Backdoor beacon to 192.168.1.200 every minute | Critical |
| Firewall | Not mentioned | Explicitly disabled at startup via `nft flush ruleset` | Critical |
| Root password | Not mentioned | Derived from hostname, trivially predictable | Critical |
| Database backup | Not mentioned | World-readable backup with plaintext credentials | Critical |
| IDS logs | Not mentioned | Startup script injects fake entries into Suricata log | High |
| Network range | 192.168.1.x | 10.42.0.0/16 | Informational |

---

## 10. Critical Findings Summary

| Finding | Severity | Flag |
| --- | --- | --- |
| Backdoor cron job beaconing to 192.168.1.200 | Critical | FLAG{CR0N_B4CKD00R} |
| Root login enabled with password auth, no VPN | Critical | FLAG{R00T_SSH_1S_D4NG3R} |
| FTP in cleartext, anonymous access enabled | Critical | FLAG{CL34RT3XT_FTP} |
| World-readable database backup with plaintext credentials | Critical | FLAG{S3NS1T1V3_B4CKUP_EXP0S3D} |
| IDS log manipulated by startup script | High | FLAG{1DS_D3T3CT10N_W0RKS} |
| Predictable root password derived from hostname | Critical | - |
| Undocumented web terminal (ttyd) running as root on port 3000 | Critical | - |
| Undocumented VS Code server running as root on port 3001 | Critical | - |
| Firewall explicitly disabled at every boot | Critical | - |
