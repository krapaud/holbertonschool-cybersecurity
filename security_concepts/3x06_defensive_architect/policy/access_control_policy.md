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

## Network

Network access must follow a default-deny approach. Only documented traffic
is allowed.

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

## Review and Removal

Access rights must be reviewed at least every quarter and after a role change.
Managers must confirm that each permission is still needed. When a person
leaves, their account, SSH keys, group memberships, badges and sessions must
be disabled or revoked without delay.

All changes must be recorded with the user, date, reason and approver. The
records will be used during the audit and kept in the project's `audit/`
directory.
