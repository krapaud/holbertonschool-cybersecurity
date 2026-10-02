#!/usr/bin/env python3

import argparse
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
    read_file(args.file)


if __name__ == "__main__":
    main()
