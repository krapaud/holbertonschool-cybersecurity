#!/usr/bin/env python3

import argparse
import configparser
import logging
import sys
from pathlib import Path

from utils import clean_data, hash_password, validate_line


MIN_LENGTH = 8
COMMON_PASSWORDS = set()
SALT = ""


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


def check_policy(password: str) -> str:
    """Check if a password follows the basic security policy."""
    if len(password) < MIN_LENGTH:
        return "WEAK"
    if password.isalpha():
        return "WEAK"
    if password.lower() in COMMON_PASSWORDS:
        return "WEAK"

    return "COMPLIANT"


def load_config() -> None:
    """Load the security settings from config.ini."""
    config_path = Path(__file__).with_name("config.ini")
    if not config_path.is_file():
        logging.error("[ERROR] Config file missing")
        sys.exit(1)

    config = configparser.ConfigParser()
    config.read(config_path)

    global MIN_LENGTH, COMMON_PASSWORDS, SALT
    security = config["SECURITY"]
    MIN_LENGTH = security.getint("MinLength")
    SALT = security.get("Salt")
    COMMON_PASSWORDS = {
        password.strip().lower()
        for password in security.get("CommonPasswords", "").split(",")
        if password.strip()
    }


def main():
    """Start BreachCheck."""
    log_format = "%(asctime)s - %(levelname)s - %(message)s"
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)

    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(logging.Formatter(log_format))

    file_handler = logging.FileHandler("breach_check.log")
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(logging.Formatter(log_format))

    logger.addHandler(console_handler)
    logger.addHandler(file_handler)
    load_config()

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

    logging.info("BreachCheck v1.0 startup...")
    logging.info("Processing file: %s", args.file)
    lines = clean_data(read_file(args.file))
    valid_lines = []
    for line_number, line in enumerate(lines, start=1):
        logging.debug("Starting regex check on line %d...", line_number)
        if validate_line(line):
            valid_lines.append(line)
            password = line.split(":", 1)[1]
            logging.debug("Password policy result: %s", check_policy(password))


if __name__ == "__main__":
    main()
