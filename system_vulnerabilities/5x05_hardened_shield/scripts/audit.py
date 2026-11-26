#!/usr/bin/env python3
"""Vérifie quelques éléments du Dockerfile du projet."""

from pathlib import Path
import json


DOSSIER_PROJET = Path(__file__).resolve().parents[1]
DOCKERFILE = DOSSIER_PROJET / "Dockerfile"


def main():
    """Affiche les vérifications et retourne un code d'erreur si besoin."""
    content = DOCKERFILE.read_text(encoding="utf-8")
    checks = {
        "Image Ubuntu 20.04": "FROM ubuntu:20.04" in content,
        "Compte applicatif non-root": "useradd --system" in content,
        "Serveur Web Nginx": "nginx" in content,
        "Serveur SSH": "openssh-server" in content,
        "Contrôle de santé": "HEALTHCHECK" in content,
        "Labels OCI": "org.opencontainers.image.title" in content,
        "Pas de mot de passe dans le Dockerfile": "DB_PASSWORD=" not in content,
        "Scripts présents": all(
            (DOSSIER_PROJET / "scripts" / name).is_file()
            for name in ("init-hardening.sh", "init-identity.sh", "init-services.sh")
        ),
    }
    report = {
        "verifications": checks,
        "reussies": sum(checks.values()),
        "total": len(checks),
    }
    print(json.dumps(report, indent=2))
    return 0 if all(checks.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
