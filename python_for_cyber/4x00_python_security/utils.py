#!/usr/bin/env python3
"""Small helper functions used by BreachCheck."""

import hashlib
import logging
import re
import sys


def read_file(filename: str):
    """Read a file one line at a time."""
    try:
        with open(filename, "r", encoding="utf-8") as file:
            for line in file:
                yield line
    except FileNotFoundError:
        logging.error("File not found: %s", filename)
        sys.exit(1)
    except PermissionError:
        logging.error("Permission denied: %s", filename)
        sys.exit(1)


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
