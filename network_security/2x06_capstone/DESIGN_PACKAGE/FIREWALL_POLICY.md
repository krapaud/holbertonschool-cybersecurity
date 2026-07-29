# FIREWALL POLICY : LogiCorp Gateway

**Client:** LogiCorp

**Consultant:** IronShield Consulting

**Date:** 2026-07-29

**Status:** Phase 3 - Design Package

---

## 1. Design Principles

The audit confirmed that the gateway has no active firewall at all. The startup script wipes every rule at boot, so the machine is completely open to anything. The goal of this policy is to fix that by applying a default deny approach: everything is blocked unless there is a specific rule that allows it.

This policy follows three rules:

- **Default deny:** if there is no rule for a connection, it is dropped.
- **Least privilege:** each zone can only reach what it strictly needs.
- **Explicit justification:** every rule exists for a documented reason, not just because it seems useful.

---

## 2. Network Zones

| Zone | Subnet | Description |
| --- | --- | --- |
| WAN | 0.0.0.0/0 | Internet, untrusted |
| DMZ | 10.0.1.0/24 | Gateway, WireGuard endpoint, SFTP server |
| LAN | 10.0.2.0/24 | Internal workstations and staff |
| Database Zone | 10.0.3.0/24 | MySQL server, isolated from everything else |
| Guest WiFi | 10.0.4.0/24 | Guest devices, internet only, no internal access |

---

## 3. Default Policies

| Chain | Default Policy | Reason |
| --- | --- | --- |
| INPUT | DROP | The gateway should only accept what is explicitly allowed |
| FORWARD | DROP | No traffic crosses zones unless a rule permits it |
| OUTPUT | ACCEPT | The gateway itself needs to reach external services to work |

These defaults are the foundation of the Zero Trust model. A machine that drops everything by default is safe even if a specific rule is missing. A machine that accepts everything by default is vulnerable the moment one rule is misconfigured.

---

## 4. Firewall Rules

### 4.1 INPUT Chain (traffic arriving at the gateway itself)

| Priority | Protocol | Source | Destination Port | Action | Justification |
| --- | --- | --- | --- | --- | --- |
| 1 | any | any | any | ACCEPT (established, related) | Allow responses to connections the gateway initiated |
| 2 | icmp | any | - | ACCEPT | Allow ping for network diagnostics |
| 3 | tcp | any | 51820 | ACCEPT | WireGuard VPN entry point, the only way in from the internet |
| 4 | tcp | VPN clients | 22 | ACCEPT | SSH administration only through VPN, never directly from internet |
| 5 | tcp | DMZ | 21 | ACCEPT | FTP legacy access during migration period only |
| 6 | any | any | any | DROP | Default deny, everything else is blocked |

**Note on rule 5:** FTP on port 21 is a temporary exception during the migration to SFTP. Once the Finance team has migrated, this rule must be removed. See the Legacy App Handling section.

**Note on rule 4:** SSH is no longer exposed to the internet. Remote administration requires connecting to WireGuard first, then SSH to the gateway. This closes the biggest attack surface identified in the audit.

### 4.2 FORWARD Chain (traffic crossing from one zone to another)

| Priority | Protocol | Source Zone | Destination Zone | Destination Port | Action | Justification |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | any | any | any | any | ACCEPT (established, related) | Allow return traffic for permitted connections |
| 2 | tcp | LAN | Database | 3306 | ACCEPT | Application servers need to reach MySQL |
| 3 | tcp | DMZ | LAN | 22 | ACCEPT | Admins connecting via VPN can SSH into internal machines |
| 4 | tcp | DMZ | Database | 3306 | ACCEPT | Admins connecting via VPN can reach the database for maintenance |
| 5 | tcp | Guest WiFi | any | 80, 443 | ACCEPT | Guests can browse the internet, nothing else |
| 6 | any | Guest WiFi | LAN | any | DROP | Guest devices can never reach internal resources |
| 7 | any | Guest WiFi | Database | any | DROP | Guest devices can never reach the database |
| 8 | any | any | any | any | DROP | Default deny for everything else |

**Note on rule 2:** Only machines in LAN can reach the database. The flat network meant any device could reach it directly. This rule replaces that situation with an explicit, auditable permission.

**Note on rules 6 and 7:** These rules are explicit even though rule 8 would cover them. The reason is to make the intent clear: guest isolation is a deliberate choice, not just a side effect of the default deny.

### 4.3 OUTPUT Chain (traffic leaving the gateway)

| Priority | Protocol | Destination | Action | Justification |
| --- | --- | --- | --- | --- |
| 1 | any | any | ACCEPT | The gateway needs outbound access to operate normally |

---

## 5. Rule Ordering Rationale

Rules are evaluated from top to bottom. The first match wins. The ordering here follows this logic:

1. **Established connections first:** this avoids breaking active sessions and is the most common case, so it goes first for performance.
2. **Explicit allows before the default drop:** each specific permission is listed before the catch-all drop at the bottom.
3. **Explicit denies before the default drop when intent matters:** guest isolation rules appear explicitly even though the default would cover them, because the security model requires that these restrictions be visible and auditable.

---

## 6. Legacy App Handling : FTP During Migration

The audit confirmed that FTP runs in cleartext with anonymous access enabled. The business constraint is that the Finance team needs FTP access during the transition to SFTP.

**Temporary approach:**

- FTP is restricted to the DMZ zone only. No machine outside DMZ can initiate an FTP connection.
- Anonymous access is disabled immediately. FTP requires a named account.
- SSL is enabled on the FTP server as an intermediate step (FTPS), even though the final solution is SFTP.
- A migration deadline is agreed with LogiCorp. On that date, the FTP rule is removed from the firewall regardless of migration status.

**Risk accepted:**

LogiCorp acknowledges that FTP, even with FTPS, is weaker than SFTP. This temporary rule is accepted as a business risk with a defined end date. IronShield Consulting recommends this window does not exceed 30 days.

---

## 7. nftables Implementation

The rules above translate to the following nftables configuration on the gateway:

```bash
#!/usr/sbin/nft -f

flush ruleset

table inet filter {

    chain input {
        type filter hook input priority 0; policy drop;

        ct state established,related accept
        icmp type echo-request accept
        udp dport 51820 accept comment "WireGuard VPN"
        ip saddr 10.8.0.0/24 tcp dport 22 accept comment "SSH via VPN only"
        ip saddr 10.0.1.0/24 tcp dport 21 accept comment "FTP legacy - temporary"
    }

    chain forward {
        type filter hook forward priority 0; policy drop;

        ct state established,related accept
        ip saddr 10.0.2.0/24 ip daddr 10.0.3.0/24 tcp dport 3306 accept comment "LAN to DB"
        ip saddr 10.8.0.0/24 ip daddr 10.0.2.0/24 tcp dport 22 accept comment "VPN to LAN SSH"
        ip saddr 10.8.0.0/24 ip daddr 10.0.3.0/24 tcp dport 3306 accept comment "VPN to DB"
        ip saddr 10.0.4.0/24 tcp dport { 80, 443 } accept comment "Guest internet only"
        ip saddr 10.0.4.0/24 ip daddr 10.0.2.0/24 drop comment "Guest blocked from LAN"
        ip saddr 10.0.4.0/24 ip daddr 10.0.3.0/24 drop comment "Guest blocked from DB"
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}
```

This configuration must be saved to a file that runs at boot, replacing the current startup script behavior of flushing all rules.
