#!/usr/bin/env python3
"""Query the local mock threat-intelligence APIs."""

from typing import Any, Dict

import requests


API_URLS = {
    "virustotal": "http://localhost:5000/virustotal/{}",
    "abuseipdb": "http://localhost:5000/abuseipdb/{}",
}


def _query_api(source: str, ip: str) -> Dict[str, Any]:
    """Return an API JSON object, or an empty dict if the request fails."""
    try:
        response = requests.get(API_URLS[source].format(ip), timeout=5)
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


def query_virustotal(ip: str) -> Dict[str, Any]:
    """Return VirusTotal mock data for an IP as a dictionary."""
    return _query_api("virustotal", ip)


def query_abuseipdb(ip: str) -> Dict[str, Any]:
    """Return AbuseIPDB mock data, including its confidence score."""
    return _query_api("abuseipdb", ip)


def main() -> None:
    """Query both mock APIs with a demonstration IP and print their results."""
    target_ip = "1.2.3.4"
    print(query_virustotal(target_ip))
    print(query_abuseipdb(target_ip))


if __name__ == "__main__":
    main()
