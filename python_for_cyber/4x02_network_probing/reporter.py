#!/usr/bin/env python3
"""Write NetProbe results to machine-readable report files."""

import json
from typing import Dict, List


def write_json_report(
    results: List[Dict[str, object]],
    output_path: str,
) -> None:
    """Write scan results as an indented JSON array.

    Args:
        results: Open-port records produced by the scanner.
        output_path: Destination path for the JSON report.

    Raises:
        OSError: If the report cannot be created or written.
    """
    with open(output_path, "w", encoding="utf-8") as report_file:
        json.dump(results, report_file, indent=2)
        report_file.write("\n")
