# Final Audit Report

## Purpose and method

This report is a self-audit of the Defensive Architect project. I checked the
policies and the four technical scripts created for Nexus Financial.

The checks below are written so that another person can repeat them on an
Ubuntu test server. The outputs shown are expected outputs. They are not a
claim that the scripts were executed on a production server.

## 1. Verification commands

### Script syntax and permissions

Run these commands from the `technical` directory:

```bash
for file in hardening.sh rbac_setup.sh network_defense.sh \
    logging_setup.sh; do
    bash -n "$file"
    test -x "$file"
    echo "$file: PASS"
done
```

Expected output:

```text
hardening.sh: PASS
rbac_setup.sh: PASS
network_defense.sh: PASS
logging_setup.sh: PASS
```

### SSH hardening

```bash
sudo sshd -T | grep -E \
    'permitrootlogin|passwordauthentication|pubkeyauthentication'
```

Expected output:

```text
permitrootlogin no
passwordauthentication no
pubkeyauthentication yes
```

Check the SSH key permissions:

```bash
sudo find /root /home -type d -name .ssh \
    -exec stat -c '%a %n' {} \;
sudo find /root /home -type f -name authorized_keys \
    -exec stat -c '%a %n' {} \;
```

Expected result:

```text
700 for .ssh directories
600 for authorized_keys files
```

### Identity and access control

```bash
getent group devs ops auditors
id sarah
id dave
sudo -l -U sarah
sudo -l -U dave
```

Expected result:

- `sarah` is a member of `devs`.
- `dave` is a member of `auditors`.
- Sarah can run only the approved Nginx commands.
- Dave can read the selected service logs.
- Neither user has unrestricted root access.

Check the sudoers file:

```bash
sudo visudo -cf /etc/sudoers.d/nexus-rbac
```

Expected output:

```text
/etc/sudoers.d/nexus-rbac: parsed OK
```

### Network defense

```bash
sudo ufw status verbose
```

Expected output must contain:

```text
Default: deny (incoming), deny (routed), allow (outgoing)
10.0.10.10  22/tcp  ALLOW IN
10.0.20.10  5432/tcp  ALLOW IN
5432/tcp  DENY IN
```

This proves that PostgreSQL is not open to `0.0.0.0/0` and that SSH is
restricted to the bastion host.

### Central logging and auditd

Check the rsyslog configuration:

```bash
sudo rsyslogd -N1
sudo grep '@@10.0.40.10:514' \
    /etc/rsyslog.d/60-nexus-central.conf
```

Expected result:

```text
rsyslogd: End of config validation run. Bye.
*.crit @@10.0.40.10:514
```

Check auditd:

```bash
sudo auditctl -s | grep enabled
sudo auditctl -l | grep -E 'passwd|sudoers|execve|-e 2'
```

Expected result:

```text
enabled 2
```

The rules should include sensitive files and privileged command execution.
The value `enabled 2` means that the audit rules are immutable until reboot.

## 2. Expected control results

### Access control

The shared SSH key is no longer part of the planned access model. Users have
individual accounts and restricted permissions. Sarah can restart Nginx, while
Dave can read logs without being able to edit configuration files.

### Network security

The database is protected by a default-deny UFW policy. Only the Web Server
private address can reach PostgreSQL. Only the bastion host can reach SSH.
The IP addresses used in the scripts are lab examples and must be replaced by
the approved deployment addresses before production use.

### Visibility

Critical and authentication logs are sent to the central logging server.
Auditd records changes to identity, SSH and sudo files, as well as commands
executed with root privileges.

### Incident response

The incident playbook gives Sarah and Dave a clear order of actions for a
compromised database. It includes evidence collection, containment,
eradication, recovery and lessons learned.

## 3. Self-assessment

### Controls that are implemented

- The threat model identifies the main technical, physical and human risks.
- The physical security plan gives low-cost actions and training steps.
- The access control policy defines individual accounts, RBAC and least
  privilege.
- The hardening script disables direct root SSH login and applies safer system
  defaults.
- The RBAC script creates users and groups and limits sudo commands.
- The network script blocks public database access with UFW.
- The logging script forwards important logs and locks audit rules.
- The incident response plan explains what to do during a database breach.

### Items still needing a real deployment test

- The scripts need to be tested on an Ubuntu virtual machine before use on a
  real server.
- The lab IP addresses must be replaced with approved network values.
- The VPN and Bali read-replica design still needs infrastructure work.
- The central log server must be reachable and tested with a real log event.
- A backup restoration test is still required.
- A legal review is required before sending any breach notification.

## Conclusion

The project provides a reasonable first security baseline for Nexus Financial.
The main risks are addressed with least privilege, network segmentation,
central logs, audit rules and an incident playbook. The result is not a
replacement for a production security review. The next step is to run the
commands above on a disposable Ubuntu server and record the real outputs in
the audit evidence folder.
