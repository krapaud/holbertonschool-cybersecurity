# Incident Response Plan

## Purpose and scope

This playbook explains what Sarah and Dave must do if the production database
is compromised. It is written for a real incident where an attacker may have
read, changed or copied customer data.

The first rule is to stay calm and record every important action. Do not
reboot the database server or delete files before collecting evidence. If the
incident includes personal or payment data, the manager and legal team must
be contacted immediately.

## Roles

- **Sarah, technical lead:** checks the application and database connection,
  applies the approved firewall changes and coordinates the technical work.
- **Dave, auditor:** collects logs, records the timeline and keeps evidence
  read-only. Dave must not edit configuration files during the investigation.
- **Manager or incident lead:** approves major business decisions, such as
  taking the database offline or restoring service.
- **Legal and privacy contact:** decides whether the incident must be
  reported to the CNIL, customers or payment partners.

Create an incident folder with the incident number and UTC time. Every note
should include the time, the person who made the change and the reason.

## 1. Identification

The incident starts when an alert, customer report or log shows unusual
database activity. Examples include repeated failed logins, a new database
administrator, unknown connections to port `5432`, unusual queries or a large
amount of data leaving the server.

Sarah and Dave should do the following:

1. Record when the alert was received and who reported it.
2. Confirm the database server name, IP address and current business impact.
3. Check whether the database is reachable from the public Internet.
4. Check active connections and recent database authentication events.
5. Compare the alert with the central rsyslog and auditd logs.
6. Decide whether this is a real compromise or a false positive.

Useful read-only commands are:

```bash
date -u
sudo ss -tulpn
sudo ss -tnp | grep ':5432'
sudo journalctl -u postgresql --since '30 minutes ago'
sudo ausearch -k privileged_commands --start recent
sudo ufw status numbered
```

Do not connect to a suspicious IP to investigate it. Save command output in
the incident folder and calculate a SHA-256 hash for exported evidence.

If customer data may have been accessed, classify the incident as high
priority and notify the incident lead and legal contact immediately.

## 2. Containment

The goal is to stop more access while keeping evidence available.

### Immediate actions

1. Keep the database server powered on. Do not reboot it.
2. Record the current connections, processes, firewall rules and time.
3. Remove the database from the public network path or load balancer.
4. Apply the approved UFW rules so port `5432` is allowed only from the
   private Web Server IP and approved administration path.
5. Block the suspicious source IP at the firewall if it is confirmed.
6. Disable compromised accounts and revoke their SSH keys.
7. Change database, application and administrator credentials through the
   approved password process.

Sarah must verify that the application still has the minimum required access.
Dave must copy the central logs before any local log rotation removes them.
The incident lead must approve a full shutdown if isolation is not enough to
stop active damage.

The containment decision must include the time, the rule that was added, the
person who approved it and the expected effect on customers.

## 3. Eradication

After containment, the team removes the attacker's access and the cause of
the compromise.

1. Preserve a copy of database, SSH, UFW, rsyslog and auditd evidence.
2. Review `/etc/passwd`, `/etc/sudoers.d/`, SSH keys and group membership.
3. Check cron jobs, systemd services and recent files for persistence.
4. Identify unauthorized database users, roles, extensions and queries.
5. Remove malicious accounts, keys, jobs and software only after recording
   and hashing the evidence.
6. Patch the database server and the application that exposed it.
7. Rotate all credentials that could have been exposed.
8. Prefer rebuilding the server from a trusted image when system integrity
   cannot be proved. Do not call a compromised server clean only because one
   process was stopped.

The team must compare the rebuilt configuration with the access control and
network policies. Root SSH login must stay disabled. PostgreSQL must not be
open to `0.0.0.0/0`. The central logging and audit rules must be active.

## 4. Recovery

Recovery starts only when the incident lead accepts the evidence and the
technical checks.

1. Restore the database from a known good backup if data was changed.
2. Check the backup date, checksum and restoration logs.
3. Test the database on an isolated network before production use.
4. Check users, permissions, firewall rules, SSH settings and audit rules.
5. Run vulnerability and malware checks on the rebuilt system.
6. Reconnect the application gradually and watch logs, connections and CPU.
7. Keep increased monitoring active for at least the first business day.
8. Tell customers and internal teams what service is available and what is
   still being investigated.

The system can return to normal operation only when the database is clean,
the original access path is fixed, monitoring is working and the incident
lead has approved the decision. Keep the original evidence read-only.

## 5. Lessons learned

Within a few business days, Sarah, Dave, the manager and the legal contact
should hold a short blameless review. The review should answer:

- How did the attacker enter the environment?
- What data was accessed, changed or copied?
- Why did the first alert or control not stop the activity?
- Which actions helped and which actions caused delays?
- What should be changed before the next incident?

Each answer must become an owner, a deadline and a technical action. Typical
actions for this environment are:

- Keep PostgreSQL behind UFW and allow only the application network and the
  approved administration path.
- Keep individual SSH keys, disabled root login and restricted sudo rules.
- Send authentication, database and audit logs to the central server.
- Review auditd alerts for privileged commands and sensitive file changes.
- Test backups and database restoration regularly.
- Add MFA to VPN and administration services.
- Train staff to report unusual access instead of hiding it.

The final report must contain the timeline, evidence hashes, impact, root
cause, decisions, notifications and the status of every improvement action.
