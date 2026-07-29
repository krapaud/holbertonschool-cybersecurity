# HARDENING : Usage Guide

This directory contains the three hardening scripts for the LogiCorp Gateway. They implement the design defined in `DESIGN_PACKAGE/` and must be run in a specific order to avoid locking yourself out.

---

## Prerequisites

- You must be connected to the gateway as root via SSH before starting.
- Your SSH public key must already be in `~/.ssh/authorized_keys` on the gateway.
- Test that key-based SSH login works **before** running `clean.sh`, because that script disables password authentication.

---

## Order of Execution

```text
1. clean.sh       (system hardening, no lockout risk)
2. vpn_setup.sh   (VPN deployment, must be verified before step 3)
3. firewall.sh    (firewall rules, panic button required)
```

Never run `firewall.sh` before `vpn_setup.sh`. If you lock SSH behind the firewall before the VPN is working, you lose access to the machine.

---

## Step 1 : clean.sh

**What it does:**

- Removes the backdoor cron job (`/etc/cron.d/logicorp`)
- Stops ttyd and openvscode-server
- Disables root login and password authentication in SSH
- Disables anonymous FTP and enables FTPS
- Fixes the startup script so firewall rules survive reboot

**How to run:**

```bash
bash clean.sh
```

**What to verify after:**

```bash
ss -tlnp | grep -E "3000|3001"   # should return nothing
curl ftp://anonymous:@localhost/  # should be rejected
```

---

## Step 2 : vpn_setup.sh

**What it does:**

- Installs WireGuard tools
- Generates the server key pair in `/etc/wireguard/`
- Creates `/etc/wireguard/wg0.conf` with commented peer blocks
- Enables IP forwarding
- Starts the WireGuard interface (`wg0` on 10.8.0.1)
- Creates a client config template in `/etc/wireguard/client_template.conf`

**How to run:**

```bash
bash vpn_setup.sh
```

**Adding users after the script runs:**

Each user generates a key pair on their own machine:

```bash
wg genkey | tee privatekey | wg pubkey > publickey
```

Then uncomment the matching `[Peer]` block in `/etc/wireguard/wg0.conf` and paste the user's public key. Apply the change without restarting:

```bash
wg syncconf wg0 <(wg-quick strip wg0)
```

**What to verify before moving to step 3:**

Connect from a client machine and confirm the tunnel is up:

```bash
ping 10.8.0.1
```

Do not run `firewall.sh` until this works.

---

## Step 3 : firewall.sh

**What it does:**

- Arms a panic button: schedules `nft flush ruleset` to run in 5 minutes via `at`
- Writes the nftables configuration to `/etc/nftables.conf`
- Applies the rules immediately

**How to run:**

```bash
bash firewall.sh
```

**The panic button:**

The script automatically schedules a firewall flush 5 minutes after it runs. If you lose access during that window, wait and the rules will be cleared so you can reconnect.

Once you have confirmed that everything still works, cancel the panic button:

```bash
atq          # shows scheduled jobs and their IDs
atrm <id>    # cancels the job
```

**What to verify after:**

```bash
# From outside the VPN - port 22 should be unreachable
ssh student@<gateway_ip>   # should time out

# From inside the VPN - SSH should work
ssh student@<gateway_ip>   # should succeed

# FTP should work for Finance users connected via VPN
curl ftp://finance_user@<gateway_ip>/
```

---

## Rollback

Each script creates a backup of the files it modifies before changing them:

| File modified | Backup location |
| --- | --- |
| `/etc/ssh/sshd_config` | `/etc/ssh/sshd_config.backup` |
| `/etc/vsftpd.conf` | `/etc/vsftpd.conf.backup` |
| `/etc/run.sh` | `/etc/run.sh.backup` |
| `/etc/nftables.conf` | No backup, flush with `nft flush ruleset` |

To restore SSH configuration:

```bash
cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
service ssh restart
```

To clear all firewall rules immediately:

```bash
nft flush ruleset
```

---

## Configuration

All IPs, ports, delays, and file paths are defined in `config.sh`. The scripts contain no hardcoded values. Edit `config.sh` if the network plan changes. Never edit values directly in the scripts.

Every value in `config.sh` can also be overridden by an environment variable without touching the file:

```bash
# Example: extend the panic button to 10 minutes
PANIC_DELAY=10 bash firewall.sh

# Example: use a different VPN port
VPN_PORT=1194 bash firewall.sh

# Example: override multiple values at once
VPN_SUBNET=192.168.10.0/24 VPN_SERVER_IP=192.168.10.1/24 bash firewall.sh
```

This is useful for testing on a different network without modifying any file.

---

## Files in This Directory

| File | Description |
| --- | --- |
| `config.sh` | All IPs, ports, and file paths. Sourced by every script, overridable via environment variable |
| `clean.sh` | System hardening : SSH, FTP, cron, unnecessary services |
| `firewall.sh` | nftables rules with default deny policy and panic button |
| `vpn_setup.sh` | WireGuard installation, key generation, and server config |
