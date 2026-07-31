# DEFENSE : Engineering Choices Under Review

**Client:** LogiCorp

**Consultant:** IronShield Consulting

**Date:** 2026-07-30

**Reviewer:** Senior Architect

---

This document answers the three challenges raised during the design review. For each one, we explain the business reasoning behind the decision, what we actually did to reduce the risk, and what risks are still there.

---

## Challenge 1 : Risk Acceptance on FTP

**Challenge:** "You kept FTP running, even tunneled over VPN. FTP is inherently insecure. Why not force the client to upgrade to SFTP?"

### Business Constraint Analysis

The brief says FTP must keep working for Finance during the transition. Forcing a switch to SFTP right now means Finance has to change tools, update scripts, and retrain their team at the exact same time we are hardening the whole system. That is two big changes at once for one team, and if FTP breaks, Finance cannot access files and that is a direct business impact.

We did not choose to keep FTP because we think it is a good solution. We kept it because the client told us we had to, and we made it as safe as possible within that constraint.

### Risk Mitigation Measures Implemented

We did not just leave FTP open. Here is what we changed:

- The firewall blocks FTP from the internet completely. Only machines connected through the VPN (10.8.0.0/24) can even reach port 21.
- Anonymous login is disabled. You need a real account to connect.
- FTPS is enabled. The server offers SSL so the connection can be encrypted if the client supports it.
- The backdoor cron job is gone. That was the biggest risk on the machine regardless of FTP.

In practice, the path to FTP now is: connect to WireGuard first, then FTP from inside the tunnel. The FTP traffic rides inside the encrypted VPN connection even though FTP itself does not encrypt.

### Residual Risk Acknowledgment

There are still risks we could not eliminate without breaking the Finance constraint:

- FTPS is available but not forced. If a Finance user has an old FTP client that does not support SSL, they will connect in cleartext inside the VPN tunnel. WireGuard encrypts the outer layer, but if the VPN is ever compromised, those credentials are exposed.
- FTP passive mode opens extra ports for the data channel, which makes the firewall rules more complex than SFTP which uses a single port.
- FTP accounts are password-based. Weak or reused passwords are still a risk.

We are acknowledging these risks. They are accepted as a business decision by LogiCorp, not recommended by us.

### Phase 2 Recommendation

FTP needs a deadline, not an open-ended exception. We recommend 30 days maximum:

1. Finance tests and validates SFTP access with their actual tools.
2. On day 30, the FTP firewall rule is removed no matter what.
3. If the deadline gets extended, we add `force_local_logins_ssl=YES` to at least force encryption as an intermediate step.
4. Once SFTP is confirmed working, vsftpd is stopped and port 21 is closed.

---

## Challenge 2 : Firewall Strategy and Lateral Movement

**Challenge:** "Explain your segmentation logic. How does it specifically prevent the lateral movement that caused the previous breach?"

### Zone Definitions and Trust Levels

The audit showed a completely flat network. Every device could reach every other device. There was nothing stopping an attacker who got on the network from going anywhere they wanted. We replaced that with defined zones, each with a clear trust level.

| Zone | Subnet | Trust Level |
| --- | --- | --- |
| WAN | 0.0.0.0/0 | Not trusted. Cannot reach anything internal directly. |
| VPN | 10.8.0.0/24 | Trusted admins after key-based authentication. |
| DMZ | 10.0.1.0/24 | The gateway itself. Handles VPN and FTP. |
| LAN | 10.0.2.0/24 | Internal workstations. Can reach the database but not from Guest. |
| Database | 10.0.3.0/24 | Isolated. Only LAN and VPN admins can reach MySQL. |
| Guest WiFi | 10.0.4.0/24 | Fully cut off from internal zones. Internet only. |

Nothing trusts anything else by default. Every connection has to be explicitly allowed.

### Traffic Flow Restrictions

The firewall has specific rules for each allowed path. It is not just a catch-all drop at the end:

- Port 51820 (WireGuard) is the only port open to the internet. Port 22 and port 21 are invisible from outside.
- SSH is only reachable from the VPN subnet. You cannot even scan for it from the internet.
- The database is only reachable from LAN machines on port 3306, and from VPN admins. Nothing else can touch it.
- Guest WiFi devices can do HTTP and HTTPS outbound. That is it. They cannot initiate any connection to LAN or the database.
- INPUT and FORWARD chains both have a default DROP policy. Anything not explicitly allowed is silently dropped.

### How the Previous Attack Path is Now Blocked

The audit found: SSH open to the internet with root login and password auth enabled, a browser-based root shell (ttyd) running without any authentication requirement, a backdoor cron job for persistence, and the database accessible from anywhere on the network.

Here is how each of those is blocked now:

- SSH from the internet: not possible. WireGuard on UDP 51820 is the only open port. An attacker scanning the internet sees nothing to attack.
- Root login over SSH: disabled. Even if someone gets past VPN, they cannot log in as root.
- Password authentication over SSH: disabled. Brute force and credential stuffing do not work. Key only.
- ttyd and openvscode-server: stopped. The browser shells are gone.
- Backdoor cron job: removed. No more persistence mechanism.
- Database from anywhere: not possible. The firewall explicitly restricts access to port 3306 to LAN and VPN subnets only.

A Guest WiFi attacker today hits a wall immediately. No SSH port, no browser shell, no path to the database.

### Defense in Depth Applied

We did not rely on one single control. We layered several independent ones so that if one fails, the others still hold:

- Layer 1: network segmentation stops traffic between zones by default.
- Layer 2: WireGuard authentication blocks anyone without a valid key pair from reaching internal services.
- Layer 3: SSH key authentication stops anyone on the VPN without the right private key.
- Layer 4: service hardening removes the extra attack surface (cron, ttyd, anonymous FTP, root SSH).

An attacker needs to break through all four layers independently to reach anything sensitive.

---

## Challenge 3 : Single Point of Failure

**Challenge:** "The Gateway is still a Single Point of Failure. What happens if it goes down?"

### Scope Acknowledgment

High availability was out of scope for this engagement. The brief was to audit and harden one existing gateway. Building a redundant architecture is a separate project with a different budget, different hardware, and coordination with LogiCorp's team to plan the failover.

We know the limitation is there. We are not pretending it is not.

### Current Risk Exposure

If the gateway fails right now:

- VPN access is gone. Remote admins cannot get in.
- Finance loses FTP access.
- Outbound routing for internal machines may break depending on how their default gateway is configured.
- The database is still reachable from on-site LAN machines, but nobody can manage the system remotely.

The biggest problem is losing remote access when something is already broken. That is exactly the worst time to need to be on-site.

### High-Level Phase 2 Plan for HA

A redundant setup would look like this:

1. A second gateway machine with the same configuration as the first.
2. keepalived running VRRP so both machines share a single virtual IP. If the primary goes down, the secondary takes the IP automatically in a few seconds.
3. WireGuard peers configured to connect to the virtual IP, not a specific machine.
4. A health check script to monitor the primary and trigger failover.

This removes the single point of failure for everything that goes through the gateway.

### Cost-Benefit Analysis

A second gateway means roughly double the hardware cost and double the configuration maintenance. Every firewall rule change, certificate renewal, and config update has to happen on both machines.

Whether that cost is worth it depends on what an hour of gateway downtime costs LogiCorp. If Finance cannot send files and admins cannot respond to incidents remotely, the cost of that downtime likely adds up fast compared to a second machine.

We recommend LogiCorp calculates that number with their finance team. Once they have an actual cost per hour of downtime, the decision becomes straightforward instead of a technical debate.

In the meantime, we recommend LogiCorp makes sure at least one person with physical access to the gateway is reachable at all times. That is the fallback while the HA project is scoped.
