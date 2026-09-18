# Access Control Policy

## Objective and Scope

This policy defines how Nexus Financial users and systems authenticate,
receive permissions and connect to the network. The goal is to protect
production and customer data without stopping developers from doing their
work.

The shared `nexus_master.pem` key must no longer be used. Every person must
use an individual account and an individual SSH key. This makes access easier
to control, review and remove.

## Authentication

The following authentication rules apply:

- Every employee must have a unique named account. Shared human accounts are
  not allowed.
- SSH access must use personal public keys. Private keys must never be stored
  in Slack, email or shared folders.
- The SSH server must use `PubkeyAuthentication yes` and
  `PasswordAuthentication no` after key-based access has been tested.
- Direct root login must be disabled with `PermitRootLogin no`.
- Administrators must use a separate named account for administration and may
  use controlled `sudo` access when required.
- The administration panel, VPN and other sensitive services must use MFA.
- SSH keys must have an owner, a creation date and a review date.
- Lost keys must be revoked immediately. Keys must also be removed when a
  person leaves the company.
- Service accounts may use restricted keys, but they must not allow interactive
  login unless there is a documented exception.

The implementation script must check the SSH configuration before applying a
change that could lock out the team. At least one tested administrative key
must exist before password authentication is disabled.

## Authorization

Access must be granted according to the user's role and work requirements.
The first roles are:

- **Developer:** access to development and approved staging resources. No
  production root access and no direct database administration.
- **Operations administrator:** controlled access to production systems using
  a named account and approved `sudo` commands.
- **Database administrator:** access to database administration tasks without
  unnecessary access to application servers.
- **Security auditor:** read-only access to logs and configuration evidence.
- **Service account:** access only to the files, ports and processes required
  by its service.

The implementation uses these Linux groups:

- `nexus-dev`: developers with development and approved staging access;
- `nexus-ops`: operations administrators;
- `nexus-dba`: database administrators;
- `nexus-auditor`: read-only security auditors;
- `nexus-service`: approved non-human service accounts.

The RBAC script must create these groups with `groupadd --force` and add users
only from an approved user list. A developer must not be added to
`nexus-ops` or `nexus-dba` unless there is a documented role change. The
script must record every `usermod --append --groups` operation.

The following rules must be implemented:

- Use role-based groups instead of adding permissions separately to each
  user.
- Apply least privilege. A user receives the smallest set of permissions
  needed for the current job.
- Do not give developers unrestricted `sudo` or a shared production key.
- Define allowed administrative commands in files under `/etc/sudoers.d/`.
- Test every sudoers change with a syntax check before enabling it.
- Keep production, staging and development permissions separate.
- Do not allow a user to approve and deploy their own high-risk change when
  separation of duties is required.
- Break-glass access must use a named emergency account, be time-limited,
  require approval and generate a log entry for later review.

The RBAC implementation script must create groups, add approved users to
those groups and apply explicit permissions. It must not silently create
privileged users or replace existing access without a backup and a log.

### Sudo Rules

The file `/etc/sudoers.d/nexus-ops` must contain only approved commands. For
example, operations administrators may use these commands:

```text
Cmnd_Alias NEXUS_OPS = /usr/bin/systemctl status nginx, \
    /usr/bin/systemctl restart nginx, \
    /usr/bin/journalctl -u nginx
%nexus-ops ALL=(root) NEXUS_OPS
```

Database administrators may use the following read and service commands:

```text
Cmnd_Alias NEXUS_DBA = /usr/bin/systemctl status postgresql, \
    /usr/bin/journalctl -u postgresql
%nexus-dba ALL=(root) NEXUS_DBA
```

The script must create the file as `root:root` with mode `0440`, then run
`visudo --check --file=/etc/sudoers.d/nexus-ops` before enabling it. No role
may receive `ALL=(ALL) ALL` and developers must not receive unrestricted
sudo.

### File and Key Permissions

The script must enforce these ownership and mode values:

- `/home/<user>/.ssh` must be owned by `<user>:<user>` with mode `0700`;
- `/home/<user>/.ssh/authorized_keys` must be owned by `<user>:<user>` with
  mode `0600`;
- private SSH keys must be owned by their user with mode `0600`;
- `/etc/ssh/sshd_config` must be owned by `root:root` with mode `0644`;
- `/etc/sudoers.d/nexus-ops` must be owned by `root:root` with mode `0440`;
- application secrets must be owned by `root:nexus-service` with mode `0640`;
- directories containing production configuration must be owned by
  `root:nexus-ops` with mode `0750`.

The script must check ownership and permissions after applying them. It must
not copy private keys into the server or create a shared key.

## Network

Network access must follow a default-deny approach. Only documented traffic
is allowed.

The following RFC1918 ranges are implementation examples for the lab. They
must be replaced by the approved network plan before production deployment:

- `VPN_CIDR=10.8.0.0/24` for administrator VPN clients;
- `ADMIN_CIDR=10.0.10.0/24` for the management network;
- `APP_CIDR=10.0.20.0/24` for application servers;
- `DB_CIDR=10.0.30.0/24` for database servers.

The firewall script must store these values in one configuration file instead
of duplicating them in several rules.

### Required Network Rules

The firewall must use a default deny policy for inbound and forwarded traffic
and must allow established connections and loopback traffic. The minimum
approved rules are:

- Allow UDP `51820` from any source to the VPN gateway for WireGuard.
- Allow TCP `22` from `VPN_CIDR` to production servers for SSH.
- Allow TCP `22` from `ADMIN_CIDR` to production servers for management.
- Allow TCP `5432` from `APP_CIDR` to database servers for applications.
- Allow TCP `5432` from `VPN_CIDR` to database servers for DBAs.
- Deny and log all other traffic to protected hosts.

Direct Internet access to TCP `22` and TCP `5432` must be denied. The script
must also allow only the documented outbound DNS, HTTPS and time services
needed by the system, and must log denied connections without filling the
disk.

- SSH must be reachable only from the approved VPN or administration
  network. The exact network ranges must be defined in the deployment
  configuration, not hard-coded from assumptions.
- PostgreSQL port `5432` must not be open to `0.0.0.0/0`.
- PostgreSQL must accept connections only from the application network and
  approved database administrators through the VPN.
- Production administration must use the VPN or an approved bastion host.
- Development and staging networks must not have unrestricted access to
  production systems or customer data.
- Firewall rules must allow only the required source, destination, protocol
  and port.
- Denied connection attempts and administrative connections must be logged.
- Network rules must be reviewed whenever a service, role or environment
  changes.

The network implementation script must apply rules in a safe order, preserve
the current administrative connection during testing and provide a rollback
or recovery procedure. It must not apply a default-deny policy before the
approved management path has been verified.

## Implementation Order

The technical scripts must follow this order:

1. Back up SSH, sudoers and firewall configuration files.
2. Create the role groups and verify the approved user mapping.
3. Install and test each user's public SSH key.
4. Validate `sshd_config` with `sshd -t`.
5. Reload SSH only after a second administrative session succeeds.
6. Create and validate the restricted sudoers files.
7. Apply file ownership and permission checks.
8. Apply firewall rules with a rollback timer and test VPN access.
9. Verify that SSH is available only through the approved management paths.

Every step must stop on an error and write a clear result to an audit log.

### Example Script Actions

The technical scripts can use actions such as these, after checking the
approved configuration:

```bash
groupadd --force nexus-dev
groupadd --force nexus-ops
groupadd --force nexus-dba
groupadd --force nexus-auditor
usermod --append --groups nexus-dev <developer>
install -o root -g root -m 0440 nexus-ops /etc/sudoers.d/nexus-ops
chown <user>:<user> /home/<user>/.ssh/authorized_keys
chmod 0600 /home/<user>/.ssh/authorized_keys
sshd -t
systemctl reload ssh
```

The placeholders must be replaced by values from an approved configuration
file. The script must validate that the user exists before running `usermod`
and must never add an unapproved user to a privileged group.

For the firewall, the script must create equivalent rules for the approved
CIDRs. For example, it must allow TCP `22` from `VPN_CIDR`, allow TCP `5432`
from `APP_CIDR`, allow TCP `5432` from `VPN_CIDR`, and deny all other traffic
to those services. It must test the rules before saving them permanently.

## Review and Removal

Access rights must be reviewed at least every quarter and after a role change.
Managers must confirm that each permission is still needed. When a person
leaves, their account, SSH keys, group memberships, badges and sessions must
be disabled or revoked without delay.

All changes must be recorded with the user, date, reason and approver. The
records will be used during the audit and kept in the project's `audit/`
directory.
