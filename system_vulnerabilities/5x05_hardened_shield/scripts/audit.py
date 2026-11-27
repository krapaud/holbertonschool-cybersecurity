#!/usr/bin/env python3
"""check_kernel_hardening() vérifie kernel hardening avec sysctl -n.
Audit aussi filesystem security.
Vérifie aussi identity security, service security et container security.
Calcule les scores par catégorie, le pourcentage global et le statut PASS/FAIL.
Génère un rapport Markdown formaté dans audit_result.md.
"""

from datetime import datetime
from pathlib import Path
import argparse
import re
import stat
import subprocess
import textwrap


DOSSIER_PROJET = Path(__file__).resolve().parents[1]
RESULTATS = []
CATEGORIES = [
    "Kernel hardening",
    "Filesystem security",
    "Identity security",
    "Service security",
    "Container security",
]


def ajouter(categorie, nom, ok, detail):
    """Ajoute un résultat à la catégorie correspondante."""
    RESULTATS.append(
        {"categorie": categorie, "nom": nom, "ok": bool(ok), "detail": detail}
    )


def lire(chemin):
    """Lit un fichier texte sans arrêter l'audit s'il manque."""
    try:
        return Path(chemin).read_text(encoding="utf-8").strip()
    except (OSError, UnicodeError):
        return ""


def directive(chemin, cle):
    """Retourne la dernière directive active d'un fichier de configuration."""
    valeur = ""
    for ligne in lire(chemin).splitlines():
        morceaux = ligne.split("#", 1)[0].split()
        if len(morceaux) > 1 and morceaux[0].lower() == cle.lower():
            valeur = " ".join(morceaux[1:])
    return valeur


def sysctl(nom):
    """Lit un paramètre noyau avec sysctl, puis dans /proc/sys si besoin."""
    try:
        resultat = subprocess.run(
            ["sysctl", "-n", nom], capture_output=True, text=True, check=False
        )
        if resultat.returncode == 0:
            return resultat.stdout.strip()
    except OSError:
        pass

    chemin = Path("/proc/sys") / nom.replace(".", "/")
    return lire(chemin)


def mode_fichier(chemin):
    """Retourne les permissions d'un fichier en octal."""
    try:
        return stat.S_IMODE(Path(chemin).stat().st_mode)
    except OSError:
        return None


def options_montage(chemin):
    """Trouve les options du montage qui contient le chemin demandé."""
    cible = str(Path(chemin).resolve())
    meilleur = ("", set())
    try:
        lignes = Path("/proc/mounts").read_text(encoding="utf-8").splitlines()
    except OSError:
        return set()

    for ligne in lignes:
        champs = ligne.split()
        if len(champs) < 4:
            continue
        point = champs[1].replace("\\040", " ")
        if cible == point or cible.startswith(point.rstrip("/") + "/"):
            if len(point) > len(meilleur[0]):
                meilleur = (point, set(champs[3].split(",")))
    return meilleur[1]


def processus_actifs():
    """Récupère les noms de processus visibles dans /proc."""
    noms = set()
    for fichier in Path("/proc").glob("[0-9]*/comm"):
        nom = lire(fichier)
        if nom:
            noms.add(nom)
    return noms


def processus_non_root(nom_voulu):
    """Cherche un processus donné lancé avec un UID non-root."""
    for fichier in Path("/proc").glob("[0-9]*/comm"):
        if lire(fichier) != nom_voulu:
            continue
        statut = lire(fichier.parent / "status")
        uid = re.search(r"(?m)^Uid:\s+(\d+)", statut)
        if uid and uid.group(1) != "0":
            return uid.group(1)
    return ""


def check_kernel_hardening():
    """Vérifie directement les paramètres sysctl de durcissement noyau."""
    kernel_rules = {
        "Routage IPv4 désactivé": ("net.ipv4.ip_forward", "0"),
        "Redirections IPv4 désactivées": ("net.ipv4.conf.all.accept_redirects", "0"),
        "Redirections IPv4 par défaut désactivées": (
            "net.ipv4.conf.default.accept_redirects", "0"
        ),
        "Envoi de redirections IPv4 désactivé": (
            "net.ipv4.conf.all.send_redirects", "0"
        ),
        "Envoi de redirections IPv4 par défaut désactivé": (
            "net.ipv4.conf.default.send_redirects", "0"
        ),
        "Filtrage de route IPv4 activé": ("net.ipv4.conf.all.rp_filter", "1"),
        "Filtrage de route IPv4 par défaut activé": (
            "net.ipv4.conf.default.rp_filter", "1"
        ),
        "SYN cookies activés": ("net.ipv4.tcp_syncookies", "1"),
        "Source routing IPv4 désactivé": (
            "net.ipv4.conf.all.accept_source_route", "0"
        ),
        "Source routing IPv4 par défaut désactivé": (
            "net.ipv4.conf.default.accept_source_route", "0"
        ),
        "ICMP broadcast ignoré": ("net.ipv4.icmp_echo_ignore_broadcasts", "1"),
        "Paquets martiens journalisés": ("net.ipv4.conf.all.log_martians", "1"),
        "Paquets martiens par défaut journalisés": (
            "net.ipv4.conf.default.log_martians", "1"
        ),
        "Redirections IPv6 désactivées": ("net.ipv6.conf.all.accept_redirects", "0"),
        "Redirections IPv6 par défaut désactivées": (
            "net.ipv6.conf.default.accept_redirects", "0"
        ),
        "Source routing IPv6 désactivé": (
            "net.ipv6.conf.all.accept_source_route", "0"
        ),
        "Source routing IPv6 par défaut désactivé": (
            "net.ipv6.conf.default.accept_source_route", "0"
        ),
        "Routage IPv6 désactivé": ("net.ipv6.conf.all.forwarding", "0"),
        "Randomisation mémoire activée": ("kernel.randomize_va_space", "2"),
        "Pointeurs noyau masqués": ("kernel.kptr_restrict", "2"),
        "Accès aux logs noyau restreint": ("kernel.dmesg_restrict", "1"),
        "Dumps SUID désactivés": ("fs.suid_dumpable", "0"),
    }
    for nom, (cle, attendu) in kernel_rules.items():
        actuel = sysctl(cle)
        ajouter("Kernel hardening", nom, actuel == attendu, actuel or "indisponible")


def check_filesystem_security():
    """Vérifie les répertoires temporaires et les fichiers sensibles."""
    for chemin in ("/tmp", "/var/tmp"):
        mode = mode_fichier(chemin)
        ok = mode is not None and mode & 0o1777 == 0o1777
        detail = f"{mode:04o}" if mode is not None else "absent"
        ajouter("Filesystem security", f"Permissions sûres sur {chemin}", ok, detail)

        options = options_montage(chemin)
        securise = {"noexec", "nosuid", "nodev"}.issubset(options)
        options_utiles = options.intersection({"noexec", "nosuid", "nodev", "ro", "rw"})
        ajouter(
            "Filesystem security",
            f"Options noexec,nosuid,nodev sur {chemin}",
            securise,
            ",".join(sorted(options_utiles)) or "options indisponibles",
        )

    for chemin in ("/etc/shadow", "/etc/gshadow"):
        mode = mode_fichier(chemin)
        ok = mode is not None and mode & 0o077 == 0
        detail = f"{mode:04o}" if mode is not None else "absent"
        ajouter("Filesystem security", f"Accès privé à {chemin}", ok, detail)

    inventaire = Path("/run/hardened-shield-suid-audit.txt")
    ajouter(
        "Filesystem security",
        "Inventaire SUID/SGID présent",
        inventaire.is_file(),
        str(inventaire) if inventaire.is_file() else "non généré",
    )


def check_identity_security():
    """Vérifie PAM, faillock, SSH et le compte root."""
    pam_password = lire("/etc/pam.d/common-password")
    pam_auth = lire("/etc/pam.d/common-auth")
    pam_account = lire("/etc/pam.d/common-account")
    pwquality = lire("/etc/security/pwquality.conf")
    faillock = lire("/etc/security/faillock.conf")
    ssh_config = "/etc/ssh/sshd_config"

    ajouter(
        "Identity security",
        "pam_pwquality actif",
        bool(re.search(r"(?m)^\s*password\s+requisite\s+pam_pwquality\.so", pam_password)),
        "common-password",
    )
    for cle, valeur in (("minlen", "12"), ("dcredit", "-1"),
                        ("ucredit", "-1"), ("lcredit", "-1"),
                        ("ocredit", "-1")):
        trouve = re.search(rf"(?m)^\s*{cle}\s*=\s*([^\s#]+)", pwquality)
        actuel = trouve.group(1) if trouve else "absent"
        ajouter("Identity security", f"Politique mot de passe {cle}", actuel == valeur, actuel)

    history_ok = bool(
        re.search(r"pam_pwhistory\.so[^\n]*remember=5[^\n]*use_authtok", pam_password)
    )
    ajouter("Identity security", "Historique de cinq mots de passe", history_ok, "PAM")

    faillock_ok = all(
        terme in pam_auth + pam_account for terme in ("pam_faillock.so", "authfail")
    ) and all(
        re.search(rf"(?m)^\s*{cle}\s*=\s*{valeur}(?:\s|$)", faillock)
        for cle, valeur in (("deny", "5"), ("unlock_time", "900"),
                            ("fail_interval", "900"))
    )
    ajouter("Identity security", "Verrouillage après cinq échecs", faillock_ok, "faillock.conf")

    for cle, attendu in (
        ("PermitRootLogin", "no"),
        ("PasswordAuthentication", "no"),
        ("PubkeyAuthentication", "yes"),
        ("AllowUsers", "shieldadmin"),
    ):
        actuel = directive(ssh_config, cle)
        ajouter("Identity security", f"SSH {cle}", actuel == attendu, actuel or "absent")

    try:
        ssh_check = subprocess.run(
            ["sshd", "-t"], capture_output=True, text=True, check=False
        )
        ssh_ok = ssh_check.returncode == 0
        ssh_detail = "configuration valide" if ssh_ok else "configuration invalide"
    except OSError:
        ssh_ok = False
        ssh_detail = "sshd indisponible"
    ajouter("Identity security", "Syntaxe de sshd_config", ssh_ok, ssh_detail)

    try:
        statut = subprocess.run(
            ["passwd", "-S", "root"], capture_output=True, text=True, check=False
        )
        verrouille = statut.returncode == 0 and len(statut.stdout.split()) > 1
        verrouille = verrouille and statut.stdout.split()[1] in {"L", "LK"}
    except OSError:
        verrouille = False
    ajouter("Identity security", "Mot de passe root verrouillé", verrouille, "passwd -S")


def check_service_security():
    """Vérifie les services attendus et l'arrêt de services inutiles."""
    actifs = processus_actifs()
    for nom, processus in (("Nginx actif", "nginx"), ("SSH actif", "sshd"),
                           ("Fail2ban actif", "fail2ban-server")):
        ok = processus in actifs
        ajouter("Service security", nom, ok, "processus présent" if ok else "processus absent")

    try:
        controle_web = subprocess.run(
            ["curl", "--fail", "--silent", "--max-time", "3",
             "http://127.0.0.1/health"],
            capture_output=True,
            text=True,
            check=False,
        )
        web_ok = controle_web.returncode == 0 and controle_web.stdout.strip() == "ok"
        web_detail = controle_web.stdout.strip() or "endpoint non joignable"
    except OSError:
        web_ok = False
        web_detail = "curl indisponible"
    ajouter("Service security", "Contrôle HTTP /health", web_ok, web_detail)

    inutiles = {"avahi-daemon", "cupsd", "rpcbind", "master", "snapd"}
    trouves = sorted(actifs.intersection(inutiles))
    ajouter(
        "Service security",
        "Services inutiles arrêtés",
        not trouves,
        ", ".join(trouves) if trouves else "aucun processus détecté",
    )


def check_container_security():
    """Vérifie les restrictions visibles depuis le conteneur courant."""
    marqueurs = Path("/.dockerenv").exists() or Path("/run/.containerenv").exists()
    ajouter("Container security", "Exécution dans un conteneur", marqueurs, "marqueur Docker/OCI")

    uid_worker = processus_non_root("nginx")
    ajouter(
        "Container security", "Worker Nginx non-root", bool(uid_worker),
        f"UID {uid_worker}" if uid_worker else "aucun worker actif",
    )

    status = lire("/proc/self/status")
    cap_eff = re.search(r"(?m)^CapEff:\s*([0-9a-fA-F]+)", status)
    cap_zero = cap_eff is not None and int(cap_eff.group(1), 16) == 0
    ajouter(
        "Container security", "Aucune capability effective", cap_zero,
        cap_eff.group(1) if cap_eff else "indisponible",
    )

    no_new_privs = re.search(r"(?m)^NoNewPrivs:\s*(\d+)", status)
    ajouter(
        "Container security", "no-new-privileges actif",
        no_new_privs is not None and no_new_privs.group(1) == "1",
        no_new_privs.group(1) if no_new_privs else "indisponible",
    )

    seccomp = re.search(r"(?m)^Seccomp:\s*(\d+)", status)
    ajouter(
        "Container security", "Filtre Seccomp actif",
        seccomp is not None and seccomp.group(1) == "2",
        seccomp.group(1) if seccomp else "indisponible",
    )

    options = options_montage("/")
    lecture = "ro" if "ro" in options else "rw"
    ajouter(
        "Container security", "Rootfs en lecture seule",
        "ro" in options, lecture,
    )

    dockerfile = lire(DOSSIER_PROJET / "Dockerfile")
    secret_absent = not re.search(r"(?im)^\s*(ENV|ARG)\s+\w*(PASSWORD|SECRET|TOKEN)\s*=", dockerfile)
    ajouter(
        "Container security", "Aucun secret intégré au Dockerfile",
        secret_absent, "Dockerfile",
    )


def faire_rapport():
    """Formate les résultats dans un rapport Markdown."""
    total = len(RESULTATS)
    reussis = sum(resultat["ok"] for resultat in RESULTATS)
    pourcentage = round(reussis * 100 / total) if total else 0
    statut = "PASS" if total and reussis == total else "FAIL"
    lignes = [
        "# Hardened Shield: rapport d'audit",
        "",
        f"- Date: {datetime.now().astimezone().strftime('%Y-%m-%d %H:%M:%S %Z')}",
        f"- Résultat global: **{statut}**",
        f"- Score: **{pourcentage}%** ({reussis}/{total})",
        "",
        "## Scores par catégorie",
        "",
    ]

    for categorie in CATEGORIES:
        resultats = [r for r in RESULTATS if r["categorie"] == categorie]
        succes = sum(r["ok"] for r in resultats)
        score = round(succes * 100 / len(resultats)) if resultats else 0
        lignes.append(f"- {categorie}: **{score}%** ({succes}/{len(resultats)})")

    lignes.extend(["", "## Détails des contrôles", ""])
    for categorie in CATEGORIES:
        resultats = [r for r in RESULTATS if r["categorie"] == categorie]
        succes = sum(r["ok"] for r in resultats)
        score = round(succes * 100 / len(resultats)) if resultats else 0
        lignes.extend(
            [f"### {categorie}: {score}% ({succes}/{len(resultats)})", ""]
        )
        for resultat in resultats:
            marque = "PASS" if resultat["ok"] else "FAIL"
            detail = resultat["detail"].replace("|", "\\|").replace("\n", " ")
            controle = f"[{marque}] {resultat['nom']}: {detail}"
            controle_lignes = textwrap.wrap(
                controle, width=76, subsequent_indent="  "
            )
            lignes.append("- " + controle_lignes[0])
            lignes.extend("  " + ligne for ligne in controle_lignes[1:])
        lignes.append("")

    lignes.extend([
        "## Conclusion",
        "",
        "Le statut PASS exige que tous les contrôles réussissent. Les contrôles",
        "de capabilities, de montage et d'exécution reflètent les options Docker",
        "réellement utilisées au lancement, et non seulement le contenu de l'image.",
        "",
    ])
    return "\n".join(lignes), reussis, total, pourcentage, statut


def main():
    """Lance les contrôles, affiche les scores et écrit le rapport."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        default=str(DOSSIER_PROJET / "audit_result.md"),
        help="fichier Markdown de sortie",
    )
    arguments = parser.parse_args()

    check_kernel_hardening()
    check_filesystem_security()
    check_identity_security()
    check_service_security()
    check_container_security()

    print("=== Hardened Shield Security Audit ===")
    for categorie in CATEGORIES:
        resultats = [r for r in RESULTATS if r["categorie"] == categorie]
        succes = sum(r["ok"] for r in resultats)
        score = round(succes * 100 / len(resultats)) if resultats else 0
        print(f"\n{categorie}: {score}% ({succes}/{len(resultats)})")
        for resultat in resultats:
            etat = "PASS" if resultat["ok"] else "FAIL"
            print(f"  [{etat}] {resultat['nom']}: {resultat['detail']}")

    rapport, reussis, total, pourcentage, statut = faire_rapport()
    sortie = Path(arguments.output)
    try:
        sortie.write_text(rapport, encoding="utf-8")
    except OSError as erreur:
        print(f"\n[ERROR] Impossible d’écrire {sortie}: {erreur}")
        return 2

    print(f"\nOverall: {pourcentage}% ({reussis}/{total}) - {statut}")
    print(f"Markdown report: {sortie}")
    return 0 if statut == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
