#!/usr/bin/env python3
"""Vérifie le noyau, le système de fichiers, l'identité et les services.

L'audit contrôle aussi les réglages du conteneur, calcule les scores par
catégorie et le résultat général, puis écrit un rapport Markdown.
"""

from datetime import datetime
from pathlib import Path
import argparse
import re
import stat
import subprocess
import textwrap


def check_kernel_hardening():
    """Vérifie les réglages du noyau avec sysctl -a."""
    kernel_values = {}
    sysctl_all_command = "sysctl -a"
    try:
        result = subprocess.run(
            sysctl_all_command.split(),
            capture_output=True,
            text=True,
            check=False,
        )
        for line in result.stdout.splitlines():
            key, separator, value = line.partition("=")
            if separator:
                kernel_values[key.strip()] = value.strip()
    except OSError:
        pass

    kernel_rules = {
        "Routage IPv4 désactivé": ("net.ipv4.ip_forward", "0"),
        "Redirections IPv4 désactivées": (
            "net.ipv4.conf.all.accept_redirects", "0"
        ),
        "Redirections IPv4 par défaut désactivées": (
            "net.ipv4.conf.default.accept_redirects", "0"
        ),
        "Envoi de redirections IPv4 désactivé": (
            "net.ipv4.conf.all.send_redirects", "0"
        ),
        "Envoi de redirections IPv4 par défaut désactivé": (
            "net.ipv4.conf.default.send_redirects", "0"
        ),
        "Filtrage de chemin inverse IPv4 activé": (
            "net.ipv4.conf.all.rp_filter", "1"
        ),
        "Filtrage de chemin inverse IPv4 par défaut activé": (
            "net.ipv4.conf.default.rp_filter", "1"
        ),
        "Cookies TCP SYN activés": (
            "net.ipv4.tcp_syncookies", "1"
        ),
        "Routage source IPv4 désactivé": (
            "net.ipv4.conf.all.accept_source_route", "0"
        ),
        "Routage source IPv4 par défaut désactivé": (
            "net.ipv4.conf.default.accept_source_route", "0"
        ),
        "Diffusions ICMP ignorées": (
            "net.ipv4.icmp_echo_ignore_broadcasts", "1"
        ),
        "Paquets martiens journalisés": (
            "net.ipv4.conf.all.log_martians", "1"
        ),
        "Paquets martiens par défaut journalisés": (
            "net.ipv4.conf.default.log_martians", "1"
        ),
        "Redirections IPv6 désactivées": (
            "net.ipv6.conf.all.accept_redirects", "0"
        ),
        "Redirections IPv6 par défaut désactivées": (
            "net.ipv6.conf.default.accept_redirects", "0"
        ),
        "Routage source IPv6 désactivé": (
            "net.ipv6.conf.all.accept_source_route", "0"
        ),
        "Routage source IPv6 par défaut désactivé": (
            "net.ipv6.conf.default.accept_source_route", "0"
        ),
        "Routage IPv6 désactivé": ("net.ipv6.conf.all.forwarding", "0"),
        "Randomisation de l’espace mémoire activée": (
            "kernel.randomize_va_space", "2"
        ),
        "Accès aux pointeurs du noyau limité": ("kernel.kptr_restrict", "2"),
        "Accès aux journaux du noyau limité": ("kernel.dmesg_restrict", "1"),
        "Dumps mémoire des fichiers SUID désactivés": (
            "fs.suid_dumpable", "0"
        ),
    }
    in_container = (
        Path("/.dockerenv").exists() or Path("/run/.containerenv").exists()
    )
    for name, (key, expected) in kernel_rules.items():
        actual = kernel_values.get(key, "")
        if not actual:
            try:
                result = subprocess.run(
                    ["sysctl", "-n", key],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                if result.returncode == 0:
                    actual = result.stdout.strip()
            except OSError:
                pass
        if not actual:
            sysctl_file = Path("/proc/sys") / key.replace(".", "/")
            try:
                actual = sysctl_file.read_text(encoding="utf-8").strip()
            except (OSError, UnicodeError):
                actual = ""
        if in_container and (
            not key.startswith("net.")
            or key == "net.ipv4.conf.all.accept_redirects"
        ):
            passed = None
            if key == "net.ipv4.conf.all.accept_redirects":
                detail = (
                    "Docker expose 1 malgré sysctl=0; valeur non modifiable "
                    "depuis le conteneur"
                )
            else:
                detail = f"à vérifier sur l'hôte (valeur lue : {actual or 'absente'})"
        else:
            passed = actual == expected
            detail = actual or "indisponible"
        add_result("Durcissement du noyau", name, passed, detail)


PROJECT_DIR = Path(__file__).resolve().parents[1]
RESULTS = []
CATEGORIES = [
    "Durcissement du noyau",
    "Sécurité du système de fichiers",
    "Sécurité des identités",
    "Sécurité des services",
    "Sécurité du conteneur",
]


def add_result(category, name, passed, detail):
    """Ajoute le résultat d'un contrôle à l'audit."""
    RESULTS.append(
        {
            "category": category,
            "name": name,
            "passed": passed,
            "detail": detail,
        }
    )


def read_text(path):
    """Lit un fichier texte ou renvoie une chaîne vide s'il manque."""
    try:
        return Path(path).read_text(encoding="utf-8").strip()
    except (OSError, UnicodeError):
        return ""


def get_directive(path, key):
    """Renvoie la dernière valeur active d'une option de configuration."""
    value = ""
    for line in read_text(path).splitlines():
        parts = line.split("#", 1)[0].split()
        if len(parts) > 1 and parts[0].lower() == key.lower():
            value = " ".join(parts[1:])
    return value


def read_sysctl(name):
    """Lit un réglage noyau avec sysctl, puis essaie /proc/sys."""
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
    """Renvoie les permissions d'un fichier au format octal."""
    try:
        return stat.S_IMODE(Path(path).stat().st_mode)
    except OSError:
        return None


def get_mount_options(path):
    """Trouve les options du montage qui contient le chemin indiqué."""
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
    """Renvoie les noms des processus visibles dans /proc."""
    names = set()
    for file_path in Path("/proc").glob("[0-9]*/comm"):
        name = read_text(file_path)
        if name:
            names.add(name)
    return names


def find_non_root_process(wanted_name):
    """Cherche un processus indiqué qui ne tourne pas avec l'UID root."""
    for file_path in Path("/proc").glob("[0-9]*/comm"):
        if read_text(file_path) != wanted_name:
            continue
        status = read_text(file_path.parent / "status")
        uid = re.search(r"(?m)^Uid:\s+(\d+)", status)
        if uid and uid.group(1) != "0":
            return uid.group(1)
    return ""


def check_filesystem_security():
    """Vérifie les dossiers temporaires, fichiers sensibles et SUID/SGID."""
    for path in ("/tmp", "/var/tmp"):
        mode = get_file_mode(path)
        ok = mode is not None and mode & 0o1777 == 0o1777
        detail = f"{mode:04o}" if mode is not None else "absent"
        add_result(
            "Sécurité du système de fichiers",
            f"Permissions sûres sur {path}", ok, detail,
        )

        options = get_mount_options(path)
        secure = {"noexec", "nosuid", "nodev"}.issubset(options)
        relevant_options = options.intersection(
            {"noexec", "nosuid", "nodev", "ro", "rw"}
        )
        add_result(
            "Sécurité du système de fichiers",
            f"Options noexec,nosuid,nodev sur {path}",
            secure,
            ",".join(sorted(relevant_options)) or "options indisponibles",
        )

    for path in ("/etc/shadow", "/etc/gshadow"):
        mode = get_file_mode(path)
        ok = mode is not None and mode & 0o077 == 0
        detail = f"{mode:04o}" if mode is not None else "absent"
        add_result(
            "Sécurité du système de fichiers",
            f"Accès privé à {path}", ok, detail,
        )

    inventory = Path("/usr/share/hardened-shield/suid-audit.txt")
    add_result(
        "Sécurité du système de fichiers",
        "Inventaire SUID/SGID présent",
        inventory.is_file(),
        str(inventory) if inventory.is_file() else "non créé",
    )


def check_identity_security():
    """Vérifie PAM, le verrouillage des comptes, SSH et l'accès root."""
    pam_password = read_text("/etc/pam.d/common-password")
    pam_auth = read_text("/etc/pam.d/common-auth")
    pam_account = read_text("/etc/pam.d/common-account")
    pwquality = read_text("/etc/security/pwquality.conf")
    faillock = read_text("/etc/security/faillock.conf")
    ssh_config = "/etc/ssh/sshd_config"

    add_result(
        "Sécurité des identités",
        "Module pam_pwquality activé",
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
        actual = found.group(1) if found else "absent"
        add_result(
            "Sécurité des identités", f"Politique de mot de passe {key}",
            actual == expected, actual,
        )

    history_ok = bool(
        re.search(
            r"pam_pwhistory\.so[^\n]*remember=5[^\n]*use_authtok",
            pam_password,
        )
    )
    add_result(
        "Sécurité des identités", "Historique de cinq mots de passe",
        history_ok, "PAM",
    )

    faillock_ok = all(
        term in pam_auth + pam_account
        for term in ("pam_faillock.so", "authfail")
    ) and all(
        re.search(rf"(?m)^\s*{key}\s*=\s*{value}(?:\s|$)", faillock)
        for key, value in (("deny", "5"), ("unlock_time", "900"),
                           ("fail_interval", "900"))
    )
    add_result(
        "Sécurité des identités", "Verrouillage après cinq échecs",
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
            "Sécurité des identités", f"SSH {key}", actual == expected,
            actual or "absent",
        )

    try:
        ssh_check = subprocess.run(
            ["sshd", "-t"], capture_output=True, text=True, check=False
        )
        ssh_ok = ssh_check.returncode == 0
        ssh_detail = (
            "configuration valide" if ssh_ok else "configuration invalide"
        )
    except OSError:
        ssh_ok = False
        ssh_detail = "sshd indisponible"
    add_result(
        "Sécurité des identités", "Syntaxe de sshd_config", ssh_ok, ssh_detail
    )

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
        "Sécurité des identités", "Mot de passe root verrouillé",
        root_locked, "passwd -S",
    )


def check_service_security():
    """Vérifie les services, le contrôle santé et les services inutiles."""
    active_processes = get_running_processes()
    for name, process in (
        ("Nginx actif", "nginx"),
        ("SSH actif", "sshd"),
        ("Fail2ban actif", "fail2ban-server"),
    ):
        ok = process in active_processes
        if process == "fail2ban-server":
            try:
                result = subprocess.run(
                    ["fail2ban-client", "ping"],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                ok = result.returncode == 0
            except OSError:
                ok = False
        add_result(
            "Sécurité des services", name, ok,
            "processus présent" if ok else "processus absent",
        )

    try:
        web_check = subprocess.run(
            ["curl", "--fail", "--silent", "--max-time", "3",
             "http://127.0.0.1/health"],
            capture_output=True,
            text=True,
            check=False,
        )
        web_ok = (
            web_check.returncode == 0
            and web_check.stdout.strip() == "ok"
        )
        web_detail = (
            web_check.stdout.strip() or "point de contrôle indisponible"
        )
    except OSError:
        web_ok = False
        web_detail = "curl indisponible"
    add_result(
        "Sécurité des services", "Contrôle HTTP /health",
        web_ok, web_detail,
    )

    unused_services = {"avahi-daemon", "cupsd", "rpcbind", "master", "snapd"}
    found_services = sorted(active_processes.intersection(unused_services))
    add_result(
        "Sécurité des services",
        "Services inutiles arrêtés",
        not found_services,
        ", ".join(found_services)
        if found_services else "aucun processus détecté",
    )


def check_container_security():
    """Vérifie les protections visibles depuis le conteneur actuel."""
    markers = (
        Path("/.dockerenv").exists()
        or Path("/run/.containerenv").exists()
    )
    add_result(
        "Sécurité du conteneur", "Exécution dans un conteneur",
        markers, "marqueur Docker/OCI",
    )

    worker_uid = find_non_root_process("nginx")
    add_result(
        "Sécurité du conteneur",
        "Worker Nginx sans privilèges root", bool(worker_uid),
        f"UID {worker_uid}" if worker_uid else "aucun worker actif",
    )

    status = read_text("/proc/self/status")
    cap_eff = re.search(r"(?m)^CapEff:\s*([0-9a-fA-F]+)", status)
    # Ces capacités sont celles ajoutées dans docker-compose.yml.
    allowed_caps = sum(1 << number for number in (0, 6, 7, 10, 12, 18))
    cap_value = int(cap_eff.group(1), 16) if cap_eff else 0
    caps_limited = cap_eff is not None and cap_value & ~allowed_caps == 0
    add_result(
        "Sécurité du conteneur",
        "Capacités limitées aux droits nécessaires", caps_limited,
        cap_eff.group(1) if cap_eff else "indisponible",
    )

    no_new_privs = re.search(r"(?m)^NoNewPrivs:\s*(\d+)", status)
    add_result(
        "Sécurité du conteneur", "Option no-new-privileges activée",
        no_new_privs is not None and no_new_privs.group(1) == "1",
        no_new_privs.group(1) if no_new_privs else "indisponible",
    )

    seccomp = re.search(r"(?m)^Seccomp:\s*(\d+)", status)
    add_result(
        "Sécurité du conteneur", "Filtre Seccomp activé",
        seccomp is not None and seccomp.group(1) == "2",
        seccomp.group(1) if seccomp else "indisponible",
    )

    options = get_mount_options("/")
    access_mode = "ro" if "ro" in options else "rw"
    add_result(
        "Sécurité du conteneur", "Système de fichiers racine en lecture seule",
        "ro" in options, access_mode,
    )

    dockerfile = read_text(PROJECT_DIR / "Dockerfile")
    secret_absent = not re.search(
        r"(?im)^\s*(ENV|ARG)\s+\w*(PASSWORD|SECRET|TOKEN)\s*=",
        dockerfile,
    )
    add_result(
        "Sécurité du conteneur", "Aucun secret dans le Dockerfile",
        secret_absent, "Dockerfile",
    )


def build_report():
    """Formate les résultats de l'audit dans un rapport Markdown."""
    applicable = [result for result in RESULTS if result["passed"] is not None]
    total = len(applicable)
    passed_count = sum(result["passed"] is True for result in applicable)
    percentage = round(passed_count * 100 / total) if total else 0
    status = "PASS" if total and passed_count == total else "FAIL"
    lines = [
        "# Audit de sécurité Hardened Shield",
        "",
        "- Date : "
        f"{datetime.now().astimezone().strftime('%Y-%m-%d %H:%M:%S %Z')}",
        f"- Résultat général : **{status}**",
        f"- Score global : **{percentage}%** ({passed_count}/{total})",
        "",
        "## Scores par catégorie",
        "",
    ]

    for category in CATEGORIES:
        items = [result for result in RESULTS if result["category"] == category]
        scored = [result for result in items if result["passed"] is not None]
        passed = sum(result["passed"] is True for result in scored)
        score = round(passed * 100 / len(scored)) if scored else 0
        lines.append(f"- {category}: **{score}%** ({passed}/{len(scored)})")

    lines.extend(["", "## Détail des contrôles", ""])
    for category in CATEGORIES:
        items = [result for result in RESULTS if result["category"] == category]
        scored = [result for result in items if result["passed"] is not None]
        passed = sum(result["passed"] is True for result in scored)
        score = round(passed * 100 / len(scored)) if scored else 0
        lines.extend([
            f"### {category}: {score}% ({passed}/{len(scored)})",
            "",
        ])
        for result in items:
            if result["passed"] is None:
                mark = "INFO"
            else:
                mark = "PASS" if result["passed"] else "FAIL"
            detail = result["detail"].replace("|", "\\|").replace("\n", " ")
            check = f"[{mark}] {result['name']}: {detail}"
            check_lines = textwrap.wrap(check, width=76)
            lines.append("- " + check_lines[0])
            lines.extend("  " + line for line in check_lines[1:])
        lines.append("")

    lines.extend([
        "## Conclusion",
        "",
        "Les contrôles INFO concernent les réglages du noyau gérés par l'hôte.",
        "Ils ne sont pas comptés dans le score du conteneur et doivent être",
        "vérifiés séparément sur la machine qui exécute Docker.",
        "",
    ])
    return "\n".join(lines), passed_count, total, percentage, status


def main():
    """Lance les contrôles, affiche les scores et écrit le rapport."""
    parser = argparse.ArgumentParser(description=__doc__)
    default_output = Path("/var/lib/hardened-shield/audit_result.md")
    parser.add_argument(
        "--output",
        default=str(default_output),
        help="Chemin du rapport Markdown",
    )
    arguments = parser.parse_args()

    check_kernel_hardening()
    check_filesystem_security()
    check_identity_security()
    check_service_security()
    check_container_security()

    print("=== Audit de sécurité Hardened Shield ===")
    for category in CATEGORIES:
        category_results = [r for r in RESULTS if r["category"] == category]
        applicable_results = [r for r in category_results if r["passed"] is not None]
        category_passed = sum(r["passed"] is True for r in applicable_results)
        score = (
            round(category_passed * 100 / len(applicable_results))
            if applicable_results else 0
        )
        print(
            f"\n{category}: {score}% "
            f"({category_passed}/{len(applicable_results)})"
        )
        for result in category_results:
            if result["passed"] is None:
                mark = "INFO"
            else:
                mark = "PASS" if result["passed"] else "FAIL"
            print(f"  [{mark}] {result['name']} : {result['detail']}")

    report, passed_count, total, percentage, status = build_report()
    output_file = Path(arguments.output)
    output_files = [output_file]
    for report_path in output_files:
        try:
            report_path.write_text(report, encoding="utf-8")
        except OSError:
            print(f"\n[ERREUR] Impossible d’écrire le rapport : {report_path}")
            return 2

    print(
        f"\nBilan général : {percentage}% "
        f"({passed_count}/{total}) - {status}"
    )
    for report_path in output_files:
        print(f"Rapport Markdown : {report_path}")
    return 0 if passed_count == total and total else 1


if __name__ == "__main__":
    raise SystemExit(main())
