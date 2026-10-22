#!/usr/bin/env python3
"""Command-line entry point for the IntelBroker investigation tool."""

import argparse
import asyncio
from typing import List, Optional

if __package__:
    from .api_client import (
        API_URLS,
        _query_api,
        _query_api_async,
        fetch_api,
        gather_intel,
        query_abuseipdb,
        query_virustotal,
    )
    from .models import TargetDossier
    from .scanner import parse_nmap_xml, run_nmap
    from .utils import (
        CACHE_FILE,
        CACHE_TTL,
        load_cached_intel,
        save_cached_intel,
        save_report,
    )
else:
    from api_client import (
        API_URLS,
        _query_api,
        _query_api_async,
        fetch_api,
        gather_intel,
        query_abuseipdb,
        query_virustotal,
    )
    from models import TargetDossier
    from scanner import parse_nmap_xml, run_nmap
    from utils import (
        CACHE_FILE,
        CACHE_TTL,
        load_cached_intel,
        save_cached_intel,
        save_report,
    )


async def _main_async(
    ip: str,
    output_path: Optional[str] = None,
    verbose: bool = False,
) -> None:
    """Gather API intelligence and Nmap results concurrently for an IP."""
    if verbose:
        print("[+] Querying VirusTotal...")
        print("[+] Querying Shodan...")
        print("[+] Querying AbuseIPDB...")

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
        if verbose:
            print("[+] Nmap finished.")
        try:
            dossier.nmap_ports = parse_nmap_xml(nmap_result)
        except ValueError as error:
            print(f"[ERROR] Nmap scan failed: {error}")

    print(f"Target: {dossier.ip}")
    if dossier.vt_data.get("error"):
        print("VirusTotal: Unavailable")
    else:
        print(
            "VirusTotal: score={score}, malicious={malicious}".format(
                score=dossier.vt_data.get("reputation_score", "unknown"),
                malicious=dossier.vt_data.get("malicious", "unknown"),
            )
        )
    if dossier.shodan_data.get("error"):
        print("Shodan: Unavailable")
    else:
        print(
            "Shodan: OS={os}, ISP={isp}, ports={ports}".format(
                os=dossier.shodan_data.get("os", "unknown"),
                isp=dossier.shodan_data.get("isp", "unknown"),
                ports=dossier.shodan_data.get("ports", []),
            )
        )
    if dossier.abuse_data.get("error"):
        print("AbuseIPDB: Unavailable")
    else:
        print(
            "AbuseIPDB: confidence={score}, reports={reports}".format(
                score=dossier.abuse_data.get(
                    "abuse_confidence_score", "unknown"
                ),
                reports=dossier.abuse_data.get("reports", "unknown"),
            )
        )
    print(f"Nmap open ports: {dossier.nmap_ports}")
    if output_path:
        try:
            save_report(dossier, output_path)
            if verbose:
                print("[SUCCESS] Report generated.")
            else:
                print(f"JSON report saved to {output_path}")
        except RuntimeError as error:
            print(f"[ERROR] {error}")


def main(argv: Optional[List[str]] = None) -> None:
    """Parse command-line options and run the asynchronous investigation."""
    parser = argparse.ArgumentParser(
        description="Collect local Nmap and simulated threat intelligence."
    )
    parser.add_argument("ip", help="IP address to investigate")
    parser.add_argument(
        "-o",
        "--output",
        help="write the complete intelligence dossier to a JSON file",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="print progress messages during the investigation",
    )
    arguments = parser.parse_args(argv)

    try:
        if arguments.verbose:
            asyncio.run(
                _main_async(
                    arguments.ip,
                    arguments.output,
                    verbose=True,
                )
            )
        else:
            asyncio.run(_main_async(arguments.ip, arguments.output))
    except (RuntimeError, asyncio.TimeoutError) as error:
        print(f"[ERROR] Investigation failed: {error}")


if __name__ == "__main__":
    main()
