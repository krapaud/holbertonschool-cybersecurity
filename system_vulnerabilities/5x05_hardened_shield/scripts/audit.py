#!/usr/bin/env python3
"""Audit simple des exigences statiques de l'image The Hardened Shield."""

from pathlib import Path
import json


ROOT = Path(__file__).resolve().parents[1]
DOCKERFILE = ROOT / "Dockerfile"


def main():
    """Affiche les contrôles Dockerfile vérifiables sans privilèges."""
    content = DOCKERFILE.read_text(encoding="utf-8")
    checks = {
        "Ubuntu 20.04 base": "FROM ubuntu:20.04" in content,
        "Non-root application account": "useradd --system" in content,
        "Nginx web server": "nginx" in content,
        "OpenSSH server": "openssh-server" in content,
        "Health check": "HEALTHCHECK" in content,
        "OCI image labels": "org.opencontainers.image.title" in content,
        "No embedded database password": "DB_PASSWORD=" not in content,
        "Initialization scripts": all(
            (ROOT / "scripts" / name).is_file()
            for name in ("init-hardening.sh", "init-identity.sh", "init-services.sh")
        ),
    }
    report = {"checks": checks, "passed": sum(checks.values()), "total": len(checks)}
    print(json.dumps(report, indent=2))
    return 0 if all(checks.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
