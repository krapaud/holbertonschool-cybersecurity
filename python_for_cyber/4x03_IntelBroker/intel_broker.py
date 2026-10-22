#!/usr/bin/env python3
"""Query the local mock threat-intelligence APIs."""

import argparse
import asyncio
import subprocess
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

import aiohttp


API_URLS = {
    "virustotal": "http://localhost:5000/virustotal/{}",
    "shodan": "http://localhost:5000/shodan/{}",
    "abuseipdb": "http://localhost:5000/abuseipdb/{}",
}


@dataclass
class TargetDossier:
    """Store the active scan and intelligence results for one target IP."""

    ip: str = ""
    vt_data: Dict[str, Any] = field(default_factory=dict)
    shodan_data: Dict[str, Any] = field(default_factory=dict)
    abuse_data: Dict[str, Any] = field(default_factory=dict)
    nmap_ports: List[int] = field(default_factory=list)


async def fetch_api(
    session: aiohttp.ClientSession,
    url: str,
) -> Dict[str, Any]:
    """Fetch and decode a JSON object, returning an empty dict on failure."""
    try:
        async with session.get(url) as response:
            if response.status != 200:
                print(f"[ERROR] API returned HTTP {response.status}.")
                return {}
            payload = await response.json()
    except (aiohttp.ClientError, asyncio.TimeoutError) as error:
        print(f"[ERROR] API request failed: {error}")
        return {}
    except ValueError:
        print("[ERROR] API response is not valid JSON.")
        return {}

    if not isinstance(payload, dict):
        print("[ERROR] API response must be a JSON object.")
        return {}
    return payload


async def _query_api_async(source: str, ip: str) -> Dict[str, Any]:
    """Query one mock API using a short-lived asynchronous HTTP session."""
    timeout = aiohttp.ClientTimeout(total=5)
    try:
        async with aiohttp.ClientSession(timeout=timeout) as session:
            url = API_URLS[source].format(ip)
            return await fetch_api(session, url)
    except aiohttp.ClientError as error:
        print(f"[ERROR] Cannot connect to the mock API server: {error}")
        return {}


def _query_api(source: str, ip: str) -> Dict[str, Any]:
    """Run one asynchronous API query through the existing sync interface."""
    try:
        return asyncio.run(_query_api_async(source, ip))
    except RuntimeError as error:
        print(f"[ERROR] Could not run asynchronous API query: {error}")
        return {}


def query_virustotal(ip: str) -> Dict[str, Any]:
    """Return VirusTotal mock data for an IP as a dictionary."""
    return _query_api("virustotal", ip)


def query_abuseipdb(ip: str) -> Dict[str, Any]:
    """Return AbuseIPDB mock data, including its confidence score."""
    return _query_api("abuseipdb", ip)


async def gather_intel(ip: str) -> List[Dict[str, Any]]:
    """Fetch VirusTotal, Shodan, and AbuseIPDB data concurrently for an IP."""
    timeout = aiohttp.ClientTimeout(total=5)
    async with aiohttp.ClientSession(timeout=timeout) as session:
        urls = [
            API_URLS[source].format(ip)
            for source in ("virustotal", "shodan", "abuseipdb")
        ]
        return await asyncio.gather(
            *(fetch_api(session, url) for url in urls)
        )


def run_nmap(ip: str) -> str:
    """Run Nmap on TCP ports 22 and 80 and return its raw XML output."""
    command = ["nmap", "-p", "22,80", ip, "-oX", "-"]
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError as error:
        message = "Nmap is not installed or not found in PATH."
        raise RuntimeError(message) from error
    except OSError as error:
        raise RuntimeError(f"Could not run Nmap: {error}") from error

    if result.returncode != 0:
        message = result.stderr.strip() or "Nmap returned a non-zero status."
        raise RuntimeError(f"Nmap failed: {message}")
    return result.stdout


def parse_nmap_xml(xml_data: str) -> list:
    """Return port numbers whose state is open from Nmap XML output."""
    try:
        root = ET.fromstring(xml_data)
    except ET.ParseError as error:
        raise ValueError("Nmap output is not valid XML.") from error

    open_ports = []
    for port_element in root.findall(".//host/ports/port"):
        state_element = port_element.find("state")
        if (state_element is not None and
                state_element.get("state") == "open"):
            port_id = port_element.get("portid")
            if port_id is not None:
                try:
                    open_ports.append(int(port_id))
                except ValueError:
                    continue
    return open_ports


def main(argv: Optional[List[str]] = None) -> None:
    """Enrich a target IP from both APIs and Nmap, then print a summary."""
    parser = argparse.ArgumentParser(
        description="Collect local Nmap and simulated threat intelligence."
    )
    parser.add_argument("ip", help="IP address to investigate")
    arguments = parser.parse_args(argv)

    dossier = TargetDossier(ip=arguments.ip)
    try:
        (dossier.vt_data, dossier.shodan_data,
         dossier.abuse_data) = asyncio.run(gather_intel(dossier.ip))
    except (aiohttp.ClientError, asyncio.TimeoutError, RuntimeError) as error:
        print(f"[ERROR] Could not gather threat intelligence: {error}")

    try:
        nmap_xml = run_nmap(dossier.ip)
        dossier.nmap_ports = parse_nmap_xml(nmap_xml)
    except (RuntimeError, ValueError) as error:
        print(f"[ERROR] Nmap scan failed: {error}")

    print(f"Target: {dossier.ip}")
    print(
        "VirusTotal: score={score}, malicious={malicious}".format(
            score=dossier.vt_data.get("reputation_score", "unknown"),
            malicious=dossier.vt_data.get("malicious", "unknown"),
        )
    )
    print(
        "Shodan: OS={os}, ISP={isp}, ports={ports}".format(
            os=dossier.shodan_data.get("os", "unknown"),
            isp=dossier.shodan_data.get("isp", "unknown"),
            ports=dossier.shodan_data.get("ports", []),
        )
    )
    print(
        "AbuseIPDB: confidence={score}, reports={reports}".format(
            score=dossier.abuse_data.get("abuse_confidence_score", "unknown"),
            reports=dossier.abuse_data.get("reports", "unknown"),
        )
    )
    print(f"Nmap open ports: {dossier.nmap_ports}")


if __name__ == "__main__":
    main()
