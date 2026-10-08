#!/usr/bin/env python3
"""Command-line tool used to check leaked account data."""
import argparse
import configparser
import logging
from pathlib import Path
import sys

from utils import clean_data, hash_password, read_file, validate_line


MIN_LENGTH = 8
COMMON_PASSWORDS = set()
SALT = ""


def check_policy(password: str) -> str:
    """Check if a password follows the basic security policy."""
    # Short passwords and simple words are easier to guess.
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
        logging.error("[ERROR] Config file missing: config.ini")
        sys.exit(1)

    config = configparser.ConfigParser()
    config.read(config_path)

    # The rules can be changed in config.ini without changing this code.
    global MIN_LENGTH, COMMON_PASSWORDS, SALT
    security = config["SECURITY"]
    MIN_LENGTH = security.getint("MinLength", fallback=MIN_LENGTH)
    SALT = security.get("Salt", fallback="")
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
    # The file is read before the lines are cleaned and checked.
    lines = clean_data(list(read_file(args.file)))
    for line_number, line in enumerate(lines, start=1):
        logging.debug("Starting regex check on line %d...", line_number)
        if validate_line(line):
            password = line.split(":", 1)[1]
            hash_password(password, SALT)
            logging.debug("Password policy result: %s", check_policy(password))


if __name__ == "__main__":
    main()
