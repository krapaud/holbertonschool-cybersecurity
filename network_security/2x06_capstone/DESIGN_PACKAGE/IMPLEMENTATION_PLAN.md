# IMPLEMENTATION PLAN : LogiCorp Gateway

**Client:** LogiCorp

**Consultant:** IronShield Consulting

**Date:** 2026-07-29

**Status:** Phase 3 - Design Package

---

## Sources

This document is built from the following sources:

- **GAP_ANALYSIS.md** : defines the target architecture and the business constraints that must not be broken during implementation (FTP must stay available, remote access must keep working).
- **AUDIT_REPORT.md** : identifies the current state of the machine and the risks that need to be fixed. The order of operations below is designed to close the most critical risks first without locking anyone out.
- **FIREWALL_POLICY.md** : the firewall rules that will be deployed in Step 3.
- **VPN_DESIGN.md** : the WireGuard configuration that will be deployed in Step 2.

---

## 1. Guiding Principles

The audit found that the machine is currently wide open : no firewall, SSH exposed to the internet, FTP with no encryption. Fixing everything at once would be the fastest approach, but it also risks breaking access to the machine entirely if something goes wrong.

The plan below applies changes in a specific order based on two rules:

- **Never close the door you came in through before opening a new one.** The VPN is deployed and tested before SSH is locked down. If something fails, there is still a way to get back in.
- **Most critical risks first.** The cron backdoor and the anonymous FTP access are fixed early because they represent active threats. The firewall comes after the VPN so that the admin does not get locked out.

---

## 2. Implementation Sequence

### Step 1 : Remove the active backdoor

**What:** Delete the hidden cron job that contacts an external server every minute.

**Why first:** The audit found a cron job in `/etc/cron.d/logicorp` that runs `curl http://192.168.1.200/ping` as root every minute. This is an active connection leaving the machine to an unknown server. Every minute this runs, the attacker knows the machine is still up. This must stop before anything else.

**Commands:**

```bash
rm /etc/cron.d/logicorp
service cron reload
```

**Rollback:** The file can be restored from the audit report if needed. There is no legitimate use for this cron job.

**Risk of lockout:** None. This step only removes an outbound connection.

---

### Step 2 : Deploy WireGuard VPN

**What:** Install WireGuard on the gateway and create a tunnel for admin access.

**Why before SSH lockdown:** SSH is currently the only way to administer the machine. Before restricting it, a VPN must be available so the admin does not lose access when SSH is locked to VPN-only connections in Step 4.

**Commands:**

```bash
apt install wireguard -y
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
```

Then create `/etc/wireguard/wg0.conf` using the configuration from VPN_DESIGN.md with the server keys and the admin's public key.

```bash
wg-quick up wg0
systemctl enable wg-quick@wg0
```

**Verification before moving on:** Connect to the VPN from the admin machine and confirm that `ping 10.8.0.1` succeeds. Do not proceed to Step 3 until this works.

**Rollback:** `wg-quick down wg0` stops the VPN. The existing SSH access on port 22 is still open at this point.

**Risk of lockout:** None, as long as verification passes before moving to the next step.

---

### Step 3 : Disable anonymous FTP and enable FTPS

**What:** Edit `/etc/vsftpd.conf` to disable anonymous access and enable SSL.

**Why now:** Anonymous FTP is an active vulnerability. Any device on the network can connect without credentials. This is fixed early because it does not affect admin access at all.

**Changes to `/etc/vsftpd.conf`:**

```bash
anonymous_enable=NO
ssl_enable=YES
rsa_cert_file=/etc/ssl/certs/vsftpd.pem
rsa_private_key_file=/etc/ssl/private/vsftpd.key
force_local_data_ssl=YES
force_local_logins_ssl=YES
```

Generate the certificate first:

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/vsftpd.key \
  -out /etc/ssl/certs/vsftpd.pem
service vsftpd restart
```

**Verification:** Try to connect anonymously and confirm it is rejected. Connect as a named Finance user and confirm FTPS works.

**Rollback:** Restore the original `vsftpd.conf` and restart vsftpd.

**Risk of lockout:** None for admin access. Finance users need to update their FTP client to use FTPS.

---

### Step 4 : Deploy the firewall

**What:** Apply the nftables rules from FIREWALL_POLICY.md.

**Why now:** The VPN is working (Step 2), so it is safe to restrict SSH. If the firewall accidentally blocks admin SSH, the admin can reconnect via VPN, which bypasses the lockout.

**Commands:**

```bash
# Save the nftables config from FIREWALL_POLICY.md to a file
cp /etc/nftables.conf /etc/nftables.conf.backup
nano /etc/nftables.conf
nft -f /etc/nftables.conf
```

**Fix the startup script:** The current `/etc/run.sh` contains `nft flush ruleset` which wipes every rule at boot. This line must be replaced with a line that loads the saved ruleset:

```bash
# Remove this line:
nft flush ruleset

# Replace with this line:
nft -f /etc/nftables.conf
```

**Verification:** From outside the VPN, confirm that port 22 is no longer reachable directly. From inside the VPN, confirm that SSH still works. Confirm that FTP is only reachable from the DMZ subnet.

**Rollback:** `nft -f /etc/nftables.conf.backup` restores the previous state. If the machine becomes completely unreachable, the physical console or the web terminal (ttyd on port 3001, still accessible locally) can be used to fix the rules.

**Risk of lockout:** Low, because the VPN is already working. Medium if the VPN config has an error, because direct SSH access will be gone.

---

### Step 5 : Harden SSH

**What:** Edit `/etc/ssh/sshd_config` to disable root login and password authentication.

**Why last:** This is the final lockdown of direct SSH access. It is done last because all other access methods (VPN, SFTP for Finance) must be confirmed working before this step.

**Changes to `/etc/ssh/sshd_config`:**

```bash
PermitRootLogin no
PasswordAuthentication no
```

```bash
service ssh restart
```

**Verification:** Try to log in as root directly and confirm it is rejected. Try to log in with a password and confirm it is rejected. Log in with an SSH key via VPN and confirm it works.

**Rollback:** Re-enable `PermitRootLogin yes` and `PasswordAuthentication yes`, then restart SSH. If locked out, use the local web terminal (ttyd) or physical console to restore the config.

**Risk of lockout:** High if the admin does not have an SSH key set up before this step. The SSH key must be in `~/.ssh/authorized_keys` and tested before disabling password authentication.

---

### Step 6 : Stop and remove unnecessary services

**What:** Stop ttyd and openvscode-server, and remove them from the startup script.

**Why last:** These services provide a fallback in case earlier steps cause a lockout. They are removed only after everything else is confirmed working.

**Commands:**

```bash
pkill ttyd
pkill openvscode-server
```

Remove the corresponding lines from `/etc/run.sh`.

**Verification:** Confirm ports 3000 and 3001 are no longer listening:

```bash
ss -tlnp | grep -E "3000|3001"
```

**Rollback:** Restart the services manually. They are not removed from the system, only stopped.

**Risk of lockout:** None if all previous steps were verified successfully.

---

## 3. Rollback Summary

| Step | Rollback Action | Time to Recover |
| --- | --- | --- |
| Step 1 (cron) | Restore `/etc/cron.d/logicorp` from audit report | Under 1 minute |
| Step 2 (VPN) | `wg-quick down wg0` | Under 1 minute |
| Step 3 (FTP) | Restore original `vsftpd.conf`, restart vsftpd | Under 2 minutes |
| Step 4 (firewall) | `nft -f /etc/nftables.conf.backup` | Under 1 minute |
| Step 5 (SSH) | Re-enable root login and password auth, restart SSH | Under 2 minutes |
| Step 6 (services) | Restart ttyd and openvscode-server manually | Under 1 minute |

---

## 4. What is Not Changed Yet

The following items are not addressed in this plan because they require a longer migration process:

| Item | Reason | Next Step |
| --- | --- | --- |
| FTP to SFTP migration | Finance users need time to transition | Agreed deadline with LogiCorp, max 30 days |
| Network segmentation (subnets) | Requires changes to physical or virtual network infrastructure | Separate project with network team |
| fail2ban activation | Low priority once SSH is locked to VPN-only access | Can be added after Step 5 |
