#!/usr/bin/env python3
"""Query the local mock threat-intelligence APIs."""

from typing import Any, Dict

import requests


VIRUSTOTAL_URL = "http://localhost:5000/virustotal/{}"


def query_virustotal(ip: str) -> Dict[str, Any]:
    """Return VirusTotal mock data for an IP, or an empty dict on failure."""
    try:
        response = requests.get(VIRUSTOTAL_URL.format(ip), timeout=5)
    except requests.exceptions.ConnectionError:
        print("[ERROR] Cannot connect to the mock API server.")
        return {}
    except requests.exceptions.Timeout:
        print("[ERROR] The mock API server did not respond in time.")
        return {}
    except requests.exceptions.RequestException as error:
        print(f"[ERROR] API request failed: {error}")
        return {}

    if response.status_code != 200:
        print(f"[ERROR] API returned HTTP {response.status_code}.")
        return {}

    try:
        payload = response.json()
    except ValueError:
        print("[ERROR] API response is not valid JSON.")
        return {}

    if not isinstance(payload, dict):
        print("[ERROR] API response must be a JSON object.")
        return {}
    return payload


def main() -> None:
    """Query the mock API with a demonstration IP and print its result."""
    print(query_virustotal("1.2.3.4"))


if __name__ == "__main__":
    main()
