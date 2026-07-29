# VPN DESIGN : LogiCorp Gateway

**Client:** LogiCorp

**Consultant:** IronShield Consulting

**Date:** 2026-07-29

**Status:** Phase 3 - Design Package

---

## Sources

This document is built from the following sources:

- **GAP_ANALYSIS.md** : identified that remote access exists but with no VPN in place. The target state requires a VPN as the single entry point from the internet, so that SSH and internal resources are never directly exposed. The Finance and Admin roles come from the business constraints section.
- **AUDIT_REPORT.md** : confirmed that no WireGuard interface exists on the gateway (`ip a` shows no `wg0`), and that SSH is currently open to the internet with root login enabled and password authentication. The VPN is the fix for that exposure.
- **WireGuard official documentation** (`man wg-quick`, wireguard.com) : source for the default port (51820), the configuration file syntax (`[Interface]` / `[Peer]`), the key generation command (`wg genkey | wg pubkey`), and the hub-and-spoke topology examples.

---

## 1. Technology Choice : WireGuard

WireGuard was already identified as the target VPN solution in GAP_ANALYSIS.md (preliminary recommendations section). This document implements that choice.

The technical reasons for choosing WireGuard over OpenVPN or IPsec are documented in the WireGuard official documentation and can be summarized as follows: WireGuard has a much smaller codebase (around 4000 lines vs over 100,000 for OpenVPN), which means a smaller attack surface and easier security auditing. It is built into the Linux kernel since version 5.6, so no additional compilation or kernel module is needed on the gateway. Its cryptography is modern and fixed, meaning there are no insecure cipher options to accidentally enable. Configuration is also significantly simpler than IPsec.

---

## 2. Topology

The VPN follows a hub-and-spoke model. The gateway in the DMZ is the hub (server). All remote workers and administrators are the spokes (clients). No client connects directly to another client.

```text
[Remote Worker]  ──┐
[Finance User]   ──┼──► [WireGuard Server on Gateway - DMZ] ──► [LAN / Database Zone]
[Administrator]  ──┘
```

The WireGuard server listens on **UDP port 51820** on the WAN interface. This is the only port that needs to be open from the internet on the gateway.

---

## 3. IP Addressing Scheme

| Interface | Network | Description |
| --- | --- | --- |
| WAN (eth1) | 10.42.x.x/16 | Public-facing interface, only UDP 51820 open |
| DMZ | 10.0.1.0/24 | Gateway internal interface |
| WireGuard (wg0) | 10.8.0.0/24 | VPN tunnel, assigned to connected clients |

**Server address:** 10.8.0.1/24 (the gateway itself on the VPN interface)

**Client addresses:** assigned sequentially starting at 10.8.0.2

| User | VPN IP | Role |
| --- | --- | --- |
| Server (gateway) | 10.8.0.1 | VPN hub |
| Admin 1 | 10.8.0.2 | Full internal access |
| Finance User 1 | 10.8.0.3 | SFTP access only |
| Finance User 2 | 10.8.0.4 | SFTP access only |

The numbers (Admin 1, Finance User 1, Finance User 2) are placeholders. In WireGuard, every individual device gets its own `[Peer]` block with its own key pair and its own IP address. Two people cannot share the same credentials. This means if LogiCorp has three Finance users, there would be three separate entries with three separate IPs. The numbering here simply shows that the pattern repeats for each person or device that needs VPN access.

---

## 4. Access Control

The VPN alone does not grant access to everything. The firewall rules in FIREWALL_POLICY.md restrict what each VPN client can reach based on their IP address inside the tunnel.

| Role | VPN IP Range | Can Reach | Cannot Reach |
| --- | --- | --- | --- |
| Administrator | 10.8.0.2 | LAN (SSH), Database (3306), DMZ | Guest WiFi zone |
| Finance User | 10.8.0.3-4 | DMZ SFTP server (port 22) | LAN, Database, Guest WiFi |

This means a Finance user who connects to the VPN can only reach the SFTP server. They cannot browse internal workstations or the database, even though they are on the VPN. The VPN authenticates who you are; the firewall decides what you can do.

---

## 5. WireGuard Server Configuration

```ini
[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = <server_private_key>

# Admin 1
[Peer]
PublicKey = <admin1_public_key>
AllowedIPs = 10.8.0.2/32

# Finance User 1
[Peer]
PublicKey = <finance1_public_key>
AllowedIPs = 10.8.0.3/32

# Finance User 2
[Peer]
PublicKey = <finance2_public_key>
AllowedIPs = 10.8.0.4/32
```

**IP notation explained (server side):**

- `Address = 10.8.0.1/24` : the server takes the address 10.8.0.1 and declares it owns the entire 10.8.0.0/24 subnet. The `/24` tells WireGuard that this machine is responsible for routing all addresses in that range.
- `AllowedIPs = 10.8.0.2/32` on a peer entry : the `/32` means "only this single IP address, nothing else." It tells the server that packets from this peer can only come from 10.8.0.2. If a peer tried to send traffic claiming to be from 10.8.0.5, the server would drop it. Using `/32` per peer is how WireGuard enforces that each client can only use its own assigned address.

---

## 6. WireGuard Client Configuration (example for Finance User)

```ini
[Interface]
Address = 10.8.0.3/24
PrivateKey = <finance1_private_key>

[Peer]
PublicKey = <server_public_key>
Endpoint = <gateway_public_ip>:51820
AllowedIPs = 10.0.1.0/24
PersistentKeepalive = 25
```

**IP notation explained (client side):**

- `Address = 10.8.0.3/24` : the client takes the address 10.8.0.3 inside the VPN tunnel.
- `AllowedIPs = 10.0.1.0/24` on the peer (server) entry : this controls what traffic the client sends through the tunnel. Only packets destined for the 10.0.1.0/24 network (the DMZ) go through WireGuard. Everything else (regular internet browsing, etc.) stays on the client's normal connection. For an admin who needs to reach the LAN and the database as well, this line would list those subnets too.

---

## 7. Key Management

WireGuard uses public/private key pairs, not passwords. Each user generates their own key pair:

```bash
wg genkey | tee privatekey | wg pubkey > publickey
```

The private key never leaves the user's machine. Only the public key is added to the server configuration. If a user leaves the company or a device is lost, the corresponding `[Peer]` block is removed from the server config and the user immediately loses access.

This is a significant improvement over the current situation where root access uses a password derived from the hostname, which anyone who sees the terminal prompt can figure out.

---

## 8. Why This Closes the Audit Findings

| Audit Finding | How VPN Fixes It |
| --- | --- |
| SSH open to the internet (FLAG{R00T_SSH_1S_D4NG3R}) | SSH port 22 is no longer open from WAN. Only UDP 51820 is open. SSH is only reachable after connecting to VPN. |
| Root login with predictable password | SSH root login is disabled entirely. VPN uses cryptographic keys, not passwords. |
| No network segmentation | VPN clients land in the 10.8.0.0/24 tunnel network. Firewall rules then control what each client can reach. |
