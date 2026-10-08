"""Small helper functions used by BreachCheck."""

import hashlib
import re


def clean_data(lines: list) -> list:
    """Clean the lines before they are processed."""
    clean_lines = []

    for line in lines:
        line = line.strip()
        if line and not line.startswith("#"):
            clean_lines.append(line)

    return clean_lines


def validate_line(line: str) -> bool:
    """Check that a line contains an email and a password."""
    pattern = r"[^@\s:]+@[^@\s:]+\.[^@\s:]+:[^:]+"
    return re.fullmatch(pattern, line) is not None


def hash_password(password: str, salt: str) -> str:
    """Hash a password with a salt using SHA-256."""
    password_bytes = password.encode("utf-8")
    salt_bytes = salt.encode("utf-8")
    return hashlib.sha256(password_bytes + salt_bytes).hexdigest()
