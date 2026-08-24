# VALIDATION : Compliance Check

This directory contains `tests.sh`, a script that verifies the hardening steps from `HARDENING/` were actually applied correctly.

Think of it like a checklist you run after assembling furniture: you go through each point one by one to make sure nothing was skipped or done wrong.

---

## How to Run

```bash
cd VALIDATION
bash tests.sh
```

The script must be run as root because some commands (`nft list ruleset`, `wg show`) require elevated privileges.

---

## What the Output Looks Like

```text
======================================================
 LogiCorp Gateway - Compliance Check
======================================================

--- Firewall ---
[PASS] Firewall default INPUT policy is DROP
[PASS] Firewall default FORWARD policy is DROP
[FAIL] WireGuard port 51820 is open in INPUT
...

======================================================
 RESULT: 15/18 checks passed
 3 check(s) failed. Review the [FAIL] lines above.
======================================================
```

Each line is either `[PASS]` or `[FAIL]` followed by a plain-English description of what was checked. At the end you get a score and the script exits with code 1 if anything failed.

---

## How the Script Works

### Counters (`PASS` and `FAIL`)

Two simple variables start at 0. Each check adds 1 to one or the other. At the end the script prints the total.

### The `check()` function

This function takes two things: a description and a command to run. If the command succeeds (exit code 0), it prints `[PASS]`. If it fails, it prints `[FAIL]`. All the repetitive if/then logic lives in one place instead of being copied 18 times.

```bash
check "SSH is running" pgrep sshd
#      ^description     ^command to run
```

### The `check_absent()` function

Same idea but inverted: it checks that something does NOT appear in the output of a command. Used to verify that `ttyd` is gone, that the cron backdoor was removed, and so on.

```bash
check_absent "ttyd is NOT running" "ttyd" pgrep -a ttyd
#             ^description          ^pattern that must NOT appear  ^command
```

### Why `shift`?

Inside the function, `$@` contains all arguments. Before running the command, the script does `shift` to remove the first argument (the description) from the list. That way `$@` contains only the command to run, not the description mixed in with it.

---

## The Four Sections

### Firewall

Checks that nftables is running with a default-deny policy on INPUT and FORWARD, that WireGuard is the only open port from the internet, and that SSH and FTP are only reachable from inside the VPN.

### Services

Checks that SSH and vsftpd are running. Checks that `ttyd` and `openvscode-server` are stopped. Checks that the backdoor cron job is gone.

### Access Control

Checks the SSH config directly: root login must be disabled, password authentication must be disabled. Checks the FTP config: anonymous access must be off, SSL must be on.

### Network Configuration

Checks that IP forwarding is enabled (required for VPN traffic to route correctly). Checks that the WireGuard interface is up with the right IP. Checks that the startup script loads firewall rules at boot instead of flushing them.

---

## What to Do When a Check Fails

Look at the `[FAIL]` line and trace it back to the relevant hardening script:

| Section | Related script |
| --- | --- |
| Firewall | `HARDENING/firewall.sh` |
| Services | `HARDENING/clean.sh` |
| Access Control | `HARDENING/clean.sh` |
| Network Configuration | `HARDENING/vpn_setup.sh` or `HARDENING/firewall.sh` |

The check descriptions are written to match the steps in those scripts, so it should be straightforward to find where something was missed.

---

## Configuration

`tests.sh` sources `HARDENING/config.sh` at startup so the expected ports, subnets, and file paths stay in sync with the hardening scripts. If you changed a value in `config.sh` (like the VPN port), the compliance checks automatically use the updated value without needing any edits here.
