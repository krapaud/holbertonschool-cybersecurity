#!/usr/bin/env python3

import argparse
import logging
import re
import sys

logger = logging.getLogger(__name__)


def read_file(filename: str) -> list:
    """Read a file and return its lines."""
    try:
        with open(filename, "r", encoding="utf-8") as file:
            return file.readlines()
    except FileNotFoundError:
        logger.error("File not found: %s", filename)
        sys.exit(1)
    except PermissionError:
        logger.error("Permission denied: %s", filename)
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
    log_format = "%(asctime)s - %(levelname)s - %(message)s"
    logger.setLevel(logging.DEBUG)

    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(logging.Formatter(log_format))

    file_handler = logging.FileHandler("breach_check.log")
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(logging.Formatter(log_format))

    logger.addHandler(console_handler)
    logger.addHandler(file_handler)

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

    logger.info("BreachCheck v1.0 startup...")
    logger.info("Processing file: %s", args.file)
    lines = clean_data(read_file(args.file))
    valid_lines = []
    for line_number, line in enumerate(lines, start=1):
        logger.debug("Starting regex check on line %d...", line_number)
        if validate_line(line):
            valid_lines.append(line)


if __name__ == "__main__":
    main()
