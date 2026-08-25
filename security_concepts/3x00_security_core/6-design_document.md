# ApexVault Security Design Document

## Executive Summary

ApexVault is a secure storage service for ApexFin's VIP clients. The design is based on three important ideas:

1. Users must prove their identity with something that is difficult to steal or phish.
2. Each person must only have the permissions needed for their job.
3. Logs must remain available even if an attacker compromises the storage server.

For authentication, ApexVault will use FIDO2 hardware security keys. For authorization, it will separate client access from administrator access. Client files will be encrypted before they are stored, and the keys needed to decrypt them will not be kept on the storage server. Finally, logs will be copied to a separate, protected logging system.

This design assumes that a server or a SysAdmin account could be compromised. The system must still protect client data and keep trustworthy evidence of what happened.

## 1. Authentication Strategy

### Selected Technology

ApexVault will use FIDO2 hardware security keys with WebAuthn. The key can require a PIN or a fingerprint before approving a login.

The rules are:

- Password-only login is not allowed.
- SMS and email codes are not used as the main authentication method.
- Every administrator must register two hardware keys. One key is kept as a recovery key.
- Clients must use a registered FIDO2 key with user verification enabled.
- Registering or replacing a key requires an authenticated user and approval from another authorized person.
- Login, key registration and account recovery actions are logged.

### Justification

FIDO2 is resistant to phishing because the hardware key checks the real website address before creating its response. A fake website cannot simply reuse that response on ApexVault.

With a password, an attacker can trick a user into typing a reusable secret into a fake website. With SMS, the code can be intercepted or the phone number can be transferred through a SIM-swap attack. With FIDO2, the private key stays inside the hardware device and is not sent to the website.

FIDO2 is not a complete solution by itself. A user can lose the key, and an attacker could try to abuse the recovery process. That is why recovery requires a second authorized person and creates an alert in the logs.

## 2. Authorization Model

### Model Selected

ApexVault will use RBAC with some ABAC checks.

RBAC means that permissions are assigned to roles. ABAC adds extra checks, such as the client who owns the file, the device used for the request and the requested action. Access is denied by default unless the complete policy allows it.

| Role | Allowed actions | Important limitation |
| --- | --- | --- |
| Client | Manage the client's own files | Cannot access another client's files |
| Storage Operator | Check storage health and capacity | Cannot read client files |
| SysAdmin | Manage the server and its services | Cannot decrypt or read client files |
| Security Auditor | Read security logs | Cannot change logs or read client files |
| Vault Security Administrator | Manage security policies and approvals | Cannot directly read client files |

The system checks the user's identity, role, client ownership and requested operation for every file request. Being successfully authenticated does not automatically give a user permission to read a file.

### Admin Restriction

The storage server must not have the keys that can decrypt client files.

The encryption process works as follows:

1. Each file is encrypted before being stored.
2. Each file receives its own encryption key.
3. That key is protected by a client-specific key stored in a separate HSM or key management service.
4. The storage server stores only encrypted files and encrypted file keys.
5. The client application can request decryption only after the authorization service has approved the request.

The SysAdmin can manage the operating system, restart services and repair storage problems. However, the SysAdmin cannot obtain the client encryption keys. Root access on the server is therefore not enough to read the files.

SELinux or a similar mandatory access control system will add another protection layer. It will restrict which services can access files and communicate with the key management service. This is useful, but it is not the main protection. The most important protection is that the decryption keys are outside the storage server.

Exceptional access, called break-glass access, must require two independent approvers, a reason, a time limit and an automatic security alert.

## 3. Accounting Architecture

### Storage Location

Logs will be sent to a centralized logging system in a separate security account and network. This system must be independent from the ApexVault storage servers.

The logs will contain, for example:

- successful and failed logins;
- file access decisions;
- key usage requests;
- administrator actions;
- permission changes;
- configuration changes;
- account recovery and break-glass actions.

The storage server can temporarily keep logs in a protected local queue if the central system is unavailable. The local copy is only a temporary buffer. The official audit record is the copy stored in the separate logging system.

### Integrity Mechanism

The central logging system will use append-only storage with a retention lock. This means that logs can be added and read, but they cannot be deleted or edited during the retention period.

Each log entry will contain the user or service responsible for the action, the time, the action performed, the result and the affected resource. Client file contents will never be written to the logs.

The collector will also calculate a cryptographic hash for each event and connect it to the previous event. If an attacker changes or removes an event, the sequence will no longer be valid. The logging system will raise an alert when this happens.

The permissions are separated:

- ApexVault administrators can send logs but cannot delete or edit them.
- Security auditors can search and read logs but cannot change them.
- The storage SysAdmin cannot access the central log storage.
- Changes to retention settings require a separate security approval and are logged.

This solves the Bob issue from Task 2 because an administrator who compromises the ApexVault server cannot erase the authoritative copy of the logs.

## Security Assumptions

- A compromised storage server must expose encrypted data, not readable client files.
- A SysAdmin account must not provide access to client decryption keys.
- A local attacker must not be able to delete the central audit record.
- Losing one hardware key must not force the company to enable password login.
- A problem sending logs to the central system must create an alert.
- If the key management service is unavailable, decryption must stop rather than bypass the security control.

## Verification Requirements

Before production, engineers must test that:

- a fake website cannot use a FIDO2 key to log in to ApexVault;
- a SysAdmin can manage the server but cannot read a client file;
- one client cannot access another client's files;
- a compromised server cannot delete the central logs;
- changing a log is detected;
- break-glass access requires the required approvals and creates an alert;
- account recovery works with the second hardware key without enabling passwords.

## Conclusion

ApexVault separates authentication, authorization, encryption and accounting. FIDO2 protects users against password phishing. External encryption keys prevent the SysAdmin from reading client files. Centralized append-only logs preserve evidence even if the storage server is compromised. These controls work together and avoid relying on one security product or one administrator.
