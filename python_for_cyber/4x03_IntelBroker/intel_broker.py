#!/usr/bin/env python3
"""Query the local mock threat-intelligence APIs."""

import argparse
import asyncio
import json
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
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


async def run_nmap(ip: str) -> str:
    """Run Nmap asynchronously and return its raw XML output."""
    command = ["nmap", "-p", "22,80", ip, "-oX", "-"]
    try:
        process = await asyncio.create_subprocess_exec(
            *command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
    except FileNotFoundError as error:
        message = "Nmap is not installed or not found in PATH."
        raise RuntimeError(message) from error
    except OSError as error:
        raise RuntimeError(f"Could not run Nmap: {error}") from error

    stdout, stderr = await process.communicate()
    if process.returncode != 0:
        error_message = stderr.decode(errors="replace").strip()
        message = error_message or "Nmap returned a non-zero status."
        raise RuntimeError(f"Nmap failed: {message}")
    return stdout.decode(errors="replace")


def save_report(dossier: TargetDossier, output_path: str) -> None:
    """Write a timestamped JSON report for a target dossier to disk."""
    report = {
        "target": dossier.ip,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "intelligence": {
            "virustotal": dossier.vt_data,
            "shodan": dossier.shodan_data,
            "abuseipdb": dossier.abuse_data,
            "nmap": {"open_ports": dossier.nmap_ports},
        },
    }
    try:
        Path(output_path).write_text(
            json.dumps(report, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    except OSError as error:
        raise RuntimeError(
            f"Could not write JSON report to {output_path}: {error}"
        ) from error


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


async def _main_async(ip: str, output_path: Optional[str] = None) -> None:
    """Gather API intelligence and Nmap results concurrently for an IP."""
    api_task = asyncio.create_task(gather_intel(ip))
    nmap_task = asyncio.create_task(run_nmap(ip))
    api_result, nmap_result = await asyncio.gather(
        api_task,
        nmap_task,
        return_exceptions=True,
    )

    dossier = TargetDossier(ip=ip)
    if isinstance(api_result, BaseException):
        print(f"[ERROR] Could not gather threat intelligence: {api_result}")
    else:
        (dossier.vt_data, dossier.shodan_data,
         dossier.abuse_data) = api_result

    if isinstance(nmap_result, BaseException):
        print(f"[ERROR] Nmap scan failed: {nmap_result}")
    else:
        try:
            dossier.nmap_ports = parse_nmap_xml(nmap_result)
        except ValueError as error:
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
    if output_path:
        try:
            save_report(dossier, output_path)
            print(f"JSON report saved to {output_path}")
        except RuntimeError as error:
            print(f"[ERROR] {error}")


def main(argv: Optional[List[str]] = None) -> None:
    """Parse arguments and start the asynchronous investigation."""
    parser = argparse.ArgumentParser(
        description="Collect local Nmap and simulated threat intelligence."
    )
    parser.add_argument("ip", help="IP address to investigate")
    parser.add_argument(
        "-o",
        "--output",
        help="write the complete intelligence dossier to a JSON file",
    )
    arguments = parser.parse_args(argv)

    try:
        asyncio.run(_main_async(arguments.ip, arguments.output))
    except (RuntimeError, asyncio.TimeoutError) as error:
        print(f"[ERROR] Investigation failed: {error}")


if __name__ == "__main__":
    main()
