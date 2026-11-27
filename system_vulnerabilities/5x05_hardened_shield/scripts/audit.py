#!/usr/bin/env python3
"""Security audit checks: kernel hardening, filesystem, identity, services,
and container security. check_kernel_hardening uses sysctl -n to check kernel
settings. The audit calculates category scores and overall PASS/FAIL status,
then writes formatted results to a Markdown report.
"""

from datetime import datetime
from pathlib import Path
import argparse
import re
import stat
import subprocess
import textwrap


def check_kernel_hardening():
    """Check kernel hardening sysctl settings."""
    kernel_rules = {
        "IPv4 forwarding disabled": ("net.ipv4.ip_forward", "0"),
        "IPv4 redirects disabled": ("net.ipv4.conf.all.accept_redirects", "0"),
        "Default IPv4 redirects disabled": (
            "net.ipv4.conf.default.accept_redirects", "0"
        ),
        "IPv4 redirect sending disabled": (
            "net.ipv4.conf.all.send_redirects", "0"
        ),
        "Default IPv4 redirect sending disabled": (
            "net.ipv4.conf.default.send_redirects", "0"
        ),
        "IPv4 reverse path filtering enabled": (
            "net.ipv4.conf.all.rp_filter", "1"
        ),
        "Default IPv4 reverse path filtering enabled": (
            "net.ipv4.conf.default.rp_filter", "1"
        ),
        "TCP SYN cookies enabled": ("net.ipv4.tcp_syncookies", "1"),
        "IPv4 source routing disabled": (
            "net.ipv4.conf.all.accept_source_route", "0"
        ),
        "Default IPv4 source routing disabled": (
            "net.ipv4.conf.default.accept_source_route", "0"
        ),
        "ICMP broadcasts ignored": (
            "net.ipv4.icmp_echo_ignore_broadcasts", "1"
        ),
        "Martian packets logged": ("net.ipv4.conf.all.log_martians", "1"),
        "Default martian packets logged": (
            "net.ipv4.conf.default.log_martians", "1"
        ),
        "IPv6 redirects disabled": ("net.ipv6.conf.all.accept_redirects", "0"),
        "Default IPv6 redirects disabled": (
            "net.ipv6.conf.default.accept_redirects", "0"
        ),
        "IPv6 source routing disabled": (
            "net.ipv6.conf.all.accept_source_route", "0"
        ),
        "Default IPv6 source routing disabled": (
            "net.ipv6.conf.default.accept_source_route", "0"
        ),
        "IPv6 forwarding disabled": ("net.ipv6.conf.all.forwarding", "0"),
        "Address space randomization enabled": (
            "kernel.randomize_va_space", "2"
        ),
        "Kernel pointers restricted": ("kernel.kptr_restrict", "2"),
        "Kernel log access restricted": ("kernel.dmesg_restrict", "1"),
        "SUID core dumps disabled": ("fs.suid_dumpable", "0"),
    }
    for name, (key, expected) in kernel_rules.items():
        actual = read_sysctl(key)
        add_result(
            "Kernel hardening", name, actual == expected,
            actual or "unavailable",
        )


PROJECT_DIR = Path(__file__).resolve().parents[1]
RESULTS = []
CATEGORIES = [
    "Kernel hardening",
    "Filesystem security",
    "Identity security",
    "Service security",
    "Container security",
]


def add_result(category, name, passed, detail):
    """Add one check result to the audit."""
    RESULTS.append(
        {
            "category": category,
            "name": name,
            "passed": bool(passed),
            "detail": detail,
        }
    )


def read_text(path):
    """Read a text file, returning an empty string when it is unavailable."""
    try:
        return Path(path).read_text(encoding="utf-8").strip()
    except (OSError, UnicodeError):
        return ""


def get_directive(path, key):
    """Return the last active setting for a key in a config file."""
    value = ""
    for line in read_text(path).splitlines():
        parts = line.split("#", 1)[0].split()
        if len(parts) > 1 and parts[0].lower() == key.lower():
            value = " ".join(parts[1:])
    return value


def read_sysctl(name):
    """Read a kernel setting with sysctl, then fall back to /proc/sys."""
    try:
        result = subprocess.run(
            ["sysctl", "-n", name], capture_output=True, text=True, check=False
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except OSError:
        pass

    path = Path("/proc/sys") / name.replace(".", "/")
    return read_text(path)


def get_file_mode(path):
    """Return file permissions in octal form."""
    try:
        return stat.S_IMODE(Path(path).stat().st_mode)
    except OSError:
        return None


def get_mount_options(path):
    """Find the mount options for the mount containing a path."""
    target = str(Path(path).resolve())
    best = ("", set())
    try:
        lines = Path("/proc/mounts").read_text(encoding="utf-8").splitlines()
    except OSError:
        return set()

    for line in lines:
        fields = line.split()
        if len(fields) < 4:
            continue
        mount_point = fields[1].replace("\\040", " ")
        inside_mount = target.startswith(mount_point.rstrip("/") + "/")
        if target == mount_point or inside_mount:
            if len(mount_point) > len(best[0]):
                best = (mount_point, set(fields[3].split(",")))
    return best[1]


def get_running_processes():
    """Return process names visible in /proc."""
    names = set()
    for file_path in Path("/proc").glob("[0-9]*/comm"):
        name = read_text(file_path)
        if name:
            names.add(name)
    return names


def find_non_root_process(wanted_name):
    """Find a named process running with a non-root UID."""
    for file_path in Path("/proc").glob("[0-9]*/comm"):
        if read_text(file_path) != wanted_name:
            continue
        status = read_text(file_path.parent / "status")
        uid = re.search(r"(?m)^Uid:\s+(\d+)", status)
        if uid and uid.group(1) != "0":
            return uid.group(1)
    return ""


def check_filesystem_security():
    """Check temporary directories, sensitive files, and SUID inventory."""
    for path in ("/tmp", "/var/tmp"):
        mode = get_file_mode(path)
        ok = mode is not None and mode & 0o1777 == 0o1777
        detail = f"{mode:04o}" if mode is not None else "absent"
        add_result(
            "Filesystem security", f"Safe permissions on {path}", ok, detail
        )

        options = get_mount_options(path)
        secure = {"noexec", "nosuid", "nodev"}.issubset(options)
        relevant_options = options.intersection(
            {"noexec", "nosuid", "nodev", "ro", "rw"}
        )
        add_result(
            "Filesystem security",
            f"noexec,nosuid,nodev options on {path}",
            secure,
            ",".join(sorted(relevant_options)) or "options unavailable",
        )

    for path in ("/etc/shadow", "/etc/gshadow"):
        mode = get_file_mode(path)
        ok = mode is not None and mode & 0o077 == 0
        detail = f"{mode:04o}" if mode is not None else "absent"
        add_result(
            "Filesystem security", f"Private access to {path}", ok, detail
        )

    inventory = Path("/run/hardened-shield-suid-audit.txt")
    add_result(
        "Filesystem security",
        "SUID/SGID inventory exists",
        inventory.is_file(),
        str(inventory) if inventory.is_file() else "not generated",
    )


def check_identity_security():
    """Check PAM password policy, account lockout, SSH, and root access."""
    pam_password = read_text("/etc/pam.d/common-password")
    pam_auth = read_text("/etc/pam.d/common-auth")
    pam_account = read_text("/etc/pam.d/common-account")
    pwquality = read_text("/etc/security/pwquality.conf")
    faillock = read_text("/etc/security/faillock.conf")
    ssh_config = "/etc/ssh/sshd_config"

    add_result(
        "Identity security",
        "pam_pwquality enabled",
        bool(re.search(
            r"(?m)^\s*password\s+requisite\s+pam_pwquality\.so",
            pam_password,
        )),
        "common-password",
    )
    for key, expected in (("minlen", "12"), ("dcredit", "-1"),
                          ("ucredit", "-1"), ("lcredit", "-1"),
                          ("ocredit", "-1")):
        found = re.search(rf"(?m)^\s*{key}\s*=\s*([^\s#]+)", pwquality)
        actual = found.group(1) if found else "missing"
        add_result(
            "Identity security", f"Password policy {key}",
            actual == expected, actual,
        )

    history_ok = bool(
        re.search(
            r"pam_pwhistory\.so[^\n]*remember=5[^\n]*use_authtok",
            pam_password,
        )
    )
    add_result("Identity security", "Five password history", history_ok, "PAM")

    faillock_ok = all(
        term in pam_auth + pam_account
        for term in ("pam_faillock.so", "authfail")
    ) and all(
        re.search(rf"(?m)^\s*{key}\s*=\s*{value}(?:\s|$)", faillock)
        for key, value in (("deny", "5"), ("unlock_time", "900"),
                           ("fail_interval", "900"))
    )
    add_result(
        "Identity security", "Lockout after five failures",
        faillock_ok, "faillock.conf",
    )

    for key, expected in (
        ("PermitRootLogin", "no"),
        ("PasswordAuthentication", "no"),
        ("PubkeyAuthentication", "yes"),
        ("AllowUsers", "shieldadmin"),
    ):
        actual = get_directive(ssh_config, key)
        add_result(
            "Identity security", f"SSH {key}", actual == expected,
            actual or "missing",
        )

    try:
        ssh_check = subprocess.run(
            ["sshd", "-t"], capture_output=True, text=True, check=False
        )
        ssh_ok = ssh_check.returncode == 0
        ssh_detail = (
            "configuration valid" if ssh_ok else "configuration invalid"
        )
    except OSError:
        ssh_ok = False
        ssh_detail = "sshd unavailable"
    add_result("Identity security", "sshd_config syntax", ssh_ok, ssh_detail)

    try:
        password_status = subprocess.run(
            ["passwd", "-S", "root"], capture_output=True,
            text=True, check=False,
        )
        root_fields = password_status.stdout.split()
        root_locked = (
            password_status.returncode == 0
            and len(root_fields) > 1
            and root_fields[1] in {"L", "LK"}
        )
    except OSError:
        root_locked = False
    add_result(
        "Identity security", "Root password locked", root_locked, "passwd -S"
    )


def check_service_security():
    """Check required services, health endpoint, and unused services."""
    active_processes = get_running_processes()
    for name, process in (
        ("Nginx active", "nginx"),
        ("SSH active", "sshd"),
        ("Fail2ban active", "fail2ban-server"),
    ):
        ok = process in active_processes
        add_result(
            "Service security", name, ok,
            "process present" if ok else "process absent",
        )

    try:
        web_check = subprocess.run(
            ["curl", "--fail", "--silent", "--max-time", "3",
             "http://127.0.0.1/health"],
            capture_output=True,
            text=True,
            check=False,
        )
        web_ok = web_check.returncode == 0 and web_check.stdout.strip() == "OK"
        web_detail = web_check.stdout.strip() or "endpoint unavailable"
    except OSError:
        web_ok = False
        web_detail = "curl unavailable"
    add_result("Service security", "HTTP /health check", web_ok, web_detail)

    unused_services = {"avahi-daemon", "cupsd", "rpcbind", "master", "snapd"}
    found_services = sorted(active_processes.intersection(unused_services))
    add_result(
        "Service security",
        "Unused services stopped",
        not found_services,
        ", ".join(found_services)
        if found_services else "no processes detected",
    )


def check_container_security():
    """Check security restrictions visible from the current container."""
    markers = (
        Path("/.dockerenv").exists()
        or Path("/run/.containerenv").exists()
    )
    add_result(
        "Container security", "Running in a container",
        markers, "Docker/OCI marker",
    )

    worker_uid = find_non_root_process("nginx")
    add_result(
        "Container security", "Non-root Nginx worker", bool(worker_uid),
        f"UID {worker_uid}" if worker_uid else "no active worker",
    )

    status = read_text("/proc/self/status")
    cap_eff = re.search(r"(?m)^CapEff:\s*([0-9a-fA-F]+)", status)
    cap_zero = cap_eff is not None and int(cap_eff.group(1), 16) == 0
    add_result(
        "Container security", "No effective capabilities", cap_zero,
        cap_eff.group(1) if cap_eff else "unavailable",
    )

    no_new_privs = re.search(r"(?m)^NoNewPrivs:\s*(\d+)", status)
    add_result(
        "Container security", "no-new-privileges enabled",
        no_new_privs is not None and no_new_privs.group(1) == "1",
        no_new_privs.group(1) if no_new_privs else "unavailable",
    )

    seccomp = re.search(r"(?m)^Seccomp:\s*(\d+)", status)
    add_result(
        "Container security", "Seccomp filter enabled",
        seccomp is not None and seccomp.group(1) == "2",
        seccomp.group(1) if seccomp else "unavailable",
    )

    options = get_mount_options("/")
    access_mode = "ro" if "ro" in options else "rw"
    add_result(
        "Container security", "Read-only root filesystem",
        "ro" in options, access_mode,
    )

    dockerfile = read_text(PROJECT_DIR / "Dockerfile")
    secret_absent = not re.search(
        r"(?im)^\s*(ENV|ARG)\s+\w*(PASSWORD|SECRET|TOKEN)\s*=",
        dockerfile,
    )
    add_result(
        "Container security", "No secrets in Dockerfile",
        secret_absent, "Dockerfile",
    )


def build_report():
    """Format audit results as a Markdown report."""
    total = len(RESULTS)
    passed_count = sum(result["passed"] for result in RESULTS)
    percentage = round(passed_count * 100 / total) if total else 0
    status = "PASS" if total and passed_count == total else "FAIL"
    lines = [
        "# Hardened Shield Security Audit",
        "",
        "- Date: "
        f"{datetime.now().astimezone().strftime('%Y-%m-%d %H:%M:%S %Z')}",
        f"- Overall status: **{status}**",
        f"- Score: **{percentage}%** ({passed_count}/{total})",
        "",
        "## Category scores",
        "",
    ]

    for category in CATEGORIES:
        category_results = [r for r in RESULTS if r["category"] == category]
        category_passed = sum(r["passed"] for r in category_results)
        score = (
            round(category_passed * 100 / len(category_results))
            if category_results else 0
        )
        lines.append(
            f"- {category}: **{score}%** "
            f"({category_passed}/{len(category_results)})"
        )

    lines.extend(["", "## Check details", ""])
    for category in CATEGORIES:
        category_results = [r for r in RESULTS if r["category"] == category]
        category_passed = sum(r["passed"] for r in category_results)
        score = (
            round(category_passed * 100 / len(category_results))
            if category_results else 0
        )
        lines.extend(
            [
                f"### {category}: {score}% "
                f"({category_passed}/{len(category_results)})",
                "",
            ]
        )
        for result in category_results:
            mark = "PASS" if result["passed"] else "FAIL"
            detail = result["detail"].replace("|", "\\|").replace("\n", " ")
            check = f"[{mark}] {result['name']}: {detail}"
            check_lines = textwrap.wrap(
                check, width=76, subsequent_indent="  "
            )
            lines.append("- " + check_lines[0])
            lines.extend("  " + line for line in check_lines[1:])
        lines.append("")

    lines.extend([
        "## Conclusion",
        "",
        "PASS requires every check to succeed. Capability, mount, and runtime",
        "checks reflect the Docker options used at container launch, not only",
        "the contents of the image.",
        "",
    ])
    return "\n".join(lines), passed_count, total, percentage, status


def main():
    """Run the checks, display scores, and write the report."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        default=str(PROJECT_DIR / "audit_result.md"),
        help="Markdown output file",
    )
    arguments = parser.parse_args()

    check_kernel_hardening()
    check_filesystem_security()
    check_identity_security()
    check_service_security()
    check_container_security()

    print("=== Hardened Shield Security Audit ===")
    for category in CATEGORIES:
        category_results = [r for r in RESULTS if r["category"] == category]
        category_passed = sum(r["passed"] for r in category_results)
        score = (
            round(category_passed * 100 / len(category_results))
            if category_results else 0
        )
        print(
            f"\n{category}: {score}% "
            f"({category_passed}/{len(category_results)})"
        )
        for result in category_results:
            mark = "PASS" if result["passed"] else "FAIL"
            print(f"  [{mark}] {result['name']}: {result['detail']}")

    report, passed_count, total, percentage, status = build_report()
    output_file = Path(arguments.output)
    try:
        output_file.write_text(report, encoding="utf-8")
    except OSError as error:
        print(f"\n[ERROR] Could not write {output_file}: {error}")
        return 2

    print(f"\nOverall: {percentage}% ({passed_count}/{total}) - {status}")
    print(f"Markdown report: {output_file}")
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
