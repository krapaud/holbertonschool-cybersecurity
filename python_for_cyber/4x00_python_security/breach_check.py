#!/usr/bin/env python3

import argparse
import re
import sys


def read_file(filename: str) -> list:
    """Read a file and return its lines."""
    try:
        with open(filename, "r", encoding="utf-8") as file:
            return file.readlines()
    except FileNotFoundError:
        print(f"[ERROR] File not found: {filename}", file=sys.stderr)
        sys.exit(1)
    except PermissionError:
        print(f"[ERROR] Permission denied: {filename}", file=sys.stderr)
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


def main():
    """Start BreachCheck."""
    parser = argparse.ArgumentParser(
        description="Check an input file for data breaches."
    )
    parser.add_argument(
        "-f", "--file", required=True,
        help="path to the file to analyze",
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true",
        help="display detailed information",
    )
    parser.add_argument(
        "-o", "--output",
        help="path for the output report file",
    )

    args = parser.parse_args()

    print("BreachCheck v1.0 startup...")
    lines = clean_data(read_file(args.file))
    valid_lines = [line for line in lines if validate_line(line)]


if __name__ == "__main__":
    main()
