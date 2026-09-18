# Threat Model

## Sources and Scope

This analysis is based on the Field Notes from the project brief. It covers
the servers, data, user accounts, workstations, network equipment and office
buildings of Nexus Financial.

The goal is to identify the most important risks before the external auditor
arrives. For each component, I selected one main threat and the actor most
likely to exploit it.

This is a first assessment. It must be completed with technical checks and
evidence during the audit and validation phases.

## Assets to Protect

The main assets to protect are:

- customer and financial data;
- the PostgreSQL database and its backups;
- SSH access to production servers;
- administrator accounts and the administration panel;
- employee MacBook workstations;
- security logs and incident evidence;
- the office, server room and network equipment.

## Threats and Risk Scenarios

STRIDE is used to classify the threats:

- **Spoofing**: pretending to be a legitimate user or device;
- **Tampering**: changing a file, configuration or piece of equipment;
- **Repudiation**: denying an action because there is no reliable evidence;
- **Information Disclosure**: accessing confidential information;
- **Denial of Service**: making a service unavailable;
- **Elevation of Privilege**: obtaining more permissions than expected.

### Building access and server room

- **Main STRIDE threat:** Tampering
- **Threat:** An unauthorized person could enter the server room and modify
  or disconnect equipment.
- **Likely actor:** Visitor or external contractor.
- **Justification:** There is no receptionist and the server room door is kept
  open with a fire extinguisher.

### MacBook workstations

- **Main STRIDE threat:** Information Disclosure
- **Threat:** Someone could read data from a workstation left unlocked.
- **Likely actor:** Unauthorized visitor.
- **Justification:** Most laptops are left unlocked during lunch or breaks.

### Whiteboard

- **Main STRIDE threat:** Information Disclosure
- **Threat:** Passwords written on the whiteboard could be read and reused.
- **Likely actor:** Visitor.
- **Justification:** The whiteboard is in an open area and contains several
  sensitive credentials.

### Unused network ports

- **Main STRIDE threat:** Elevation of Privilege
- **Threat:** A device connected to an active port could gain access to the
  internal network.
- **Likely actor:** Person with physical access to the office.
- **Justification:** Several unused switch ports are still active and the
  cables are poorly organized.

### SSH key `nexus_master.pem`

- **Main STRIDE threat:** Spoofing
- **Threat:** Someone with the key could pretend to be an administrator and
  access production.
- **Likely actor:** External attacker who obtains the key from Slack.
- **Justification:** The same private key is shared with the whole team in a
  Slack channel.

### PostgreSQL database

- **Main STRIDE threat:** Information Disclosure
- **Threat:** An attacker could connect directly from the Internet and try to
  retrieve data.
- **Likely actor:** External attacker.
- **Justification:** PostgreSQL port 5432 is open to all addresses with
  `0.0.0.0/0`.

### S3 backups

- **Main STRIDE threat:** Information Disclosure
- **Threat:** A backup containing sensitive data could be copied or exposed.
- **Likely actor:** External attacker who obtains cloud credentials.
- **Justification:** The backup script is old and has not been checked since
  Kevin left.

### Security logging

- **Main STRIDE threat:** Repudiation
- **Threat:** A malicious action could not be reliably traced or proved
  because there are no proper logs.
- **Likely actor:** Compromised user account.
- **Justification:** The company does not have a properly configured logging
  system.

### Administration panel

- **Main STRIDE threat:** Spoofing
- **Threat:** An attacker could guess the PIN and log in as an administrator.
- **Likely actor:** External attacker.
- **Justification:** The CEO wants to use his birth year, `1975`, as the PIN.

## Impact and Likelihood

The most urgent risks are the ones that could cause a data leak or direct
access to production:

1. The PostgreSQL database is exposed to the Internet and can be attacked
   directly.
2. The shared SSH key could provide privileged access to production.
3. The passwords on the whiteboard can be collected very easily.
4. Physical access and active network ports could allow an attacker to bypass
   some protections.

These risks are very likely because the weaknesses already exist and do not
require a complex attack. Their impact could be critical for a company
preparing an IPO.

## Risk Reduction Measures

The first measures to plan are:

- control access to the office and keep the server room locked;
- remove passwords from the whiteboard and use a password manager instead;
- enable automatic screen locking on workstations;
- disable unused network ports;
- replace the shared SSH key with individual and revocable keys;
- close public access to PostgreSQL and allow only approved sources;
- check backup permissions, encryption and restore procedures;
- deploy centralized and protected logging;
- replace the weak PIN with stronger authentication and enable MFA.

Each measure will be described in more detail in a policy document or a
technical script later in the project.

## Remaining Risks

Some risks will remain after these corrections. Human error, configuration
mistakes and compromised accounts cannot be completely eliminated.

Nexus Financial must continue to review access rights, test backups, check
physical security and run incident response exercises. The results of these
checks should be kept in the `audit/` directory.
