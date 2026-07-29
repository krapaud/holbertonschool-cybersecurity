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

**Discrepancy:** No VPN interface is present, which confirms that WireGuard is not installed.

### Finding : Database server location confirmed : FLAG{Z3R0_TRU5T_Z0N3S}

I read the database configuration file:

```bash
cat /etc/logicorp/db.conf
```

Output:

```text
DB_HOST=192.168.1.50
DB_PORT=3306
# FLAG{Z3R0_TRU5T_Z0N3S}
```

The database is a MySQL server at 192.168.1.50, on the same flat network as every other device. Any machine on the 192.168.1.x network can reach it directly on port 3306. There is no zone separation between the database and the rest of the infrastructure.

### Finding : Flat network confirmed : FLAG{AUD1T_FL4T_N3TW0RK}

While exploring configuration files, I found a LogiCorp-specific network configuration:

```bash
cat /etc/logicorp/network.conf
```

Output:

```text
NETWORK_MODE=FLAT
# FLAG{AUD1T_FL4T_N3TW0RK}
```

The network is explicitly configured as flat. This is the root cause of the ransomware attack: a guest WiFi device was able to reach the database directly because there was no separation between devices on the network.

---

## 3. Attack Surface

### Open TCP Ports

| Port | Service | Process | Notes |
| --- | --- | --- | --- |
| 21 | FTP | vsftpd (root) | Sends everything in cleartext, open to everyone |
| 22 | SSH | sshd (root) | Open to the internet, no VPN required |
| 3000 | Web terminal | ttyd (root) | Not in documentation, gives a root shell in the browser |
| 3001 | VS Code server | openvscode-server (root) | Not in documentation, full code editor access in the browser |

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

I read the FTP configuration file to understand how it was set up:

```bash
cat /etc/vsftpd.conf
```

Two things immediately stood out:

```text
ssl_enable=NO
anonymous_enable=YES
```

The first line means there is no encryption at all on FTP connections. The second means anyone can connect to the FTP server without a username or password. So the Finance team's files are being transferred completely in the open, and anyone can connect and browse the server without even needing an account.

---

## 4. Security Controls

| Control | Status | Notes |
| --- | --- | --- |
| Firewall (nftables) | Disabled | The startup script clears all firewall rules every time the machine boots |
| SELinux / AppArmor | Cannot be verified | Container environment, no systemd |

**How I found it:**

I read the startup script to see what the machine does when it starts:

```bash
cat /etc/run.sh
```

Inside, there is a line that deletes all firewall rules:

```bash
nft flush ruleset 2>/dev/null
```

This means even if someone adds firewall rules manually, they get wiped out every time the machine restarts. The machine has no active firewall protection.

---

## 5. User Accounts

| User | Shell | Sudo | Notes |
| --- | --- | --- | --- |
| root | /bin/bash | Full | Admin account |
| student | /bin/bash | Unknown | Audit user |
| sync | /bin/sync | None | System user |

**Commands used:**

```bash
cat /etc/passwd | grep -v nologin | grep -v false
ls -la ~/.ssh/
cat ~/.ssh/authorized_keys
```

**SSH keys:** Two SSH keys are registered for `mur.mickael@gmail.com`. Having two keys for the same person is unusual and should be checked.

### Finding : Root login activity recorded : FLAG{R00T_L0G1N_D3T3CT3D}

I found a security policy file that confirms root login attempts were noticed:

```bash
cat /etc/logicorp/security.policy
```

Output:

```text
root login should never happen
FLAG{R00T_L0G1N_D3T3CT3D}
```

The policy explicitly states root login should never happen, yet `PermitRootLogin yes` is active in the SSH config. The policy is documented but not enforced.

### Finding : Root login enabled over SSH : FLAG{R00T_SSH_1S_D4NG3R}

I read the SSH configuration file to check how SSH was set up:

```bash
cat /etc/ssh/sshd_config
```

Two dangerous settings were active:

```text
PermitRootLogin yes
PasswordAuthentication yes
```

This means anyone on the internet can try to log in directly as root using a password. There is no VPN required, no IP restriction, nothing. At the bottom of the file, hidden in a comment saying "Legacy access - do not remove", the flag was there. That kind of comment is a classic trick to make people leave the dangerous setting in place.

### Finding : Root password is easy to guess

Inside `/etc/run.sh`, the root password is set automatically at every boot:

```bash
echo root:`echo $HOSTNAME | cut -d '-' -f 1` | chpasswd
```

The hostname of the machine is visible in the terminal prompt. The password is just the first part of that hostname. So anyone who can see the hostname can figure out the root password immediately.

---

## 6. Running Services

| Service | PID | User | Notes |
| --- | --- | --- | --- |
| vsftpd | 63 | root | FTP server |
| sshd | 89 | root | SSH server |
| cron | 78 | root | Task scheduler |
| ttyd | 91 | root | Web terminal on port 3000, not in documentation |
| openvscode-server | 96/105/116 | root | VS Code in browser on port 3001, not in documentation |

**Commands used:**

```bash
ps aux
```

### Finding : Unnecessary services running as root : FLAG{UNN3C3SS4RY_S3RV1C3}

While reading LogiCorp configuration files, I found the flag in `/etc/logicorp/telnet.flag`:

```bash
cat /etc/logicorp/telnet.flag
```

Output:

```text
# FLAG{UNN3C3SS4RY_S3RV1C3}
```

Two services are running that have no business reason to exist: `ttyd` gives anyone who reaches port 3000 a full root shell in their browser, and `openvscode-server` gives full code editor access on port 3001. Both run as root and are not mentioned anywhere in the documentation. These services massively increase the attack surface of the machine.

---

## 7. Scheduled Tasks

| Schedule | User | Command | Risk |
| --- | --- | --- | --- |
| Every minute | root | `/usr/bin/curl http://192.168.1.200/ping` | Critical |

### Finding : Hidden cron job sending requests to an internal server : FLAG{CR0N_B4CKD00R}

While looking at all running processes, I noticed that root was running a `curl` command every single minute pointing to an internal address:

```text
root  173  0.0  0.0  2892  1032  ?  Ss  07:58  0:00  /bin/sh -c /usr/bin/curl http://192.168.1.200/ping
```

A root process repeatedly calling an internal server is suspicious. I looked at the scheduled tasks to find where it came from:

```bash
cat /etc/cron.d/logicorp
```

Output:

```text
* * * * * root /usr/bin/curl http://192.168.1.200/ping
# FLAG{CR0N_B4CKD00R}
```

This is a hidden task that was planted on the machine. Every minute, the server silently contacts another machine at 192.168.1.200. This is how an attacker keeps a connection to a compromised machine without needing to log in again.

---

## 8. Sensitive Data Exposure

### Finding : Database backup readable by anyone : FLAG{S3NS1T1V3_B4CKUP_EXP0S3D}

While exploring the filesystem, I found a `logicorp` folder in `/opt/`:

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

There is a database backup file that any user on the machine can read. Inside it, there is a root password stored in plain text. This means anyone who manages to get a basic account on the machine can immediately get the admin password from this file.

### Finding : Security logs can be faked : FLAG{1DS_D3T3CT10N_W0RKS}

Inside `/etc/run.sh`, the startup script writes directly into the security alert log:

```bash
echo "FLAG{1DS_D3T3CT10N_W0RKS}" >> /var/log/suricata/fast.log
```

I confirmed by reading the log:

```bash
cat /var/log/suricata/fast.log
```

The security tool that is supposed to detect attacks (Suricata) writes its alerts to a log file. But that file can be written to by anyone with access to the startup script. This means an attacker could add fake alerts to hide real ones, or delete real alerts to cover their tracks.

---

## 9. Discrepancies

| Item | Documentation | Reality | Risk |
| --- | --- | --- | --- |
| Port 3000 | Not mentioned | Web terminal running as root in browser | Critical |
| Port 3001 | Not mentioned | VS Code server running as root in browser | Critical |
| Cron job | Not mentioned | Hidden task sending requests to 192.168.1.200 every minute | Critical |
| Firewall | Not mentioned | Wiped at every boot, no rules active | Critical |
| Root password | Not mentioned | Derived from hostname, easy to figure out | Critical |
| Database backup | Not mentioned | Readable by any user, contains plain text password | Critical |
| Security logs | Not mentioned | Can be written to by startup script | High |
| Network mode | Not mentioned | `/etc/logicorp/network.conf` explicitly set to FLAT | Critical |

---

## 10. Critical Findings Summary

| Finding | Severity | Flag |
| --- | --- | --- |
| Hidden cron job contacting internal server every minute | Critical | FLAG{CR0N_B4CKD00R} |
| Root login open to the internet with no protection | Critical | FLAG{R00T_SSH_1S_D4NG3R} |
| FTP sends everything in cleartext, anyone can connect | Critical | FLAG{CL34RT3XT_FTP} |
| Database backup readable by any user, contains plain text password | Critical | FLAG{S3NS1T1V3_B4CKUP_EXP0S3D} |
| Security alert log can be faked by startup script | High | FLAG{1DS_D3T3CT10N_W0RKS} |
| Root password derived from hostname, easy to guess | Critical | - |
| Web terminal giving root access via browser on port 3000 | Critical | - |
| VS Code server giving root access via browser on port 3001 | Critical | - |
| Firewall rules wiped at every reboot | Critical | - |
| Network explicitly configured as flat in `/etc/logicorp/network.conf` | Critical | FLAG{AUD1T_FL4T_N3TW0RK} |
| Unnecessary services (ttyd, openvscode) running as root | Critical | FLAG{UNN3C3SS4RY_S3RV1C3} |
| Database (MySQL) on same flat network as all other devices | Critical | FLAG{Z3R0_TRU5T_Z0N3S} |
| Root login policy documented but not enforced | High | FLAG{R00T_L0G1N_D3T3CT3D} |
| fail2ban configured to detect SSH brute force | Informational | FLAG{SSH_BRUTE_BLOCKED} (triggers on ban) |
