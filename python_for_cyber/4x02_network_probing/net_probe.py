#!/usr/bin/env python3
"""Provide basic TCP port probing for the NetProbe tool."""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import inspect
import json
import random
import socket
import sys
import time
from typing import Optional

COMMON_SERVICES = {
    21: "FTP",
    22: "SSH",
    80: "HTTP",
    443: "HTTPS",
    3306: "MySQL",
}

KNOWN_BAD_SIGNATURES = (
    "vsftpd 2.3.4",
    "Apache 2.2.8",
)

CLI_DELAY = 0.0


def check_port(ip: str, port: int) -> bool:
    """Return whether a TCP connection can be established to ``ip:port``.

    Args:
        ip: IPv4 address or resolvable hostname to probe.
        port: TCP port number to probe.

    Returns:
        ``True`` when the connection succeeds, otherwise ``False``.
    """
    connection = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    connection.settimeout(1.0)

    try:
        connection.connect((ip, port))
        return True
    except OSError:
        return False
    finally:
        connection.close()


def ping_sweep(subnet: str) -> list:
    """Return hosts in a /24 subnet accepting TCP connections on port 80.

    Args:
        subnet: First three IPv4 octets, for example ``"192.168.1"``.

    Returns:
        A list of responsive host IP addresses from ``.1`` through ``.254``.
    """
    live_hosts = []

    for host_number in range(1, 255):
        ip_address = f"{subnet}.{host_number}"
        if check_port(ip_address, 80):
            live_hosts.append(ip_address)

    return live_hosts


def get_banner(ip: str, port: int) -> str:
    """Return the service banner received from ``ip:port``.

    Args:
        ip: IPv4 address or resolvable hostname to contact.
        port: TCP port where the service is listening.

    Returns:
        The decoded banner without surrounding whitespace, or ``"Unknown"``
        when the service does not provide a readable response.
    """
    connection = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    connection.settimeout(1.0)

    try:
        connection.connect((ip, port))
        connection.sendall(b"HEAD / HTTP/1.0\r\n\r\n")
        response = connection.recv(1024)
        if not response:
            return "Unknown"
        return response.decode("utf-8", errors="replace").strip()
    except OSError:
        return "Unknown"
    finally:
        connection.close()


def guess_service(port: int) -> str:
    """Return the conventional service name associated with a TCP port.

    Args:
        port: TCP port number to look up.

    Returns:
        A common service name, or ``"Unknown"`` when the port is not mapped.
    """
    return COMMON_SERVICES.get(port, "Unknown")


def get_service_info(ip: str, port: int) -> str:
    """Return a banner or a port-based service guess for ``ip:port``.

    Args:
        ip: IPv4 address or resolvable hostname to contact.
        port: TCP port where the service is listening.

    Returns:
        The received banner, or a conventional service name marked as
        ``"(Guessed)"`` when no banner is available.
    """
    banner = get_banner(ip, port)
    if banner != "Unknown" and banner:
        return banner

    guessed_service = guess_service(port)
    if guessed_service == "Unknown":
        return "Unknown"
    return f"{guessed_service} (Guessed)"


def check_vulnerability(banner: str) -> str:
    """Return a vulnerability marker when a banner matches a bad signature.

    Args:
        banner: Service banner to compare with known vulnerable signatures.

    Returns:
        ``"[VULNERABLE]"`` when a known signature is found, otherwise an
        empty string.
    """
    normalized_banner = banner.lower()
    for signature in KNOWN_BAD_SIGNATURES:
        if signature.lower() in normalized_banner:
            return "[VULNERABLE]"
    return ""


def scan_port_with_delay(ip: str, port: int, delay: float) -> bool:
    """Check one port after waiting for the requested stealth delay.

    Args:
        ip: IPv4 address or resolvable hostname to scan.
        port: TCP port to probe.
        delay: Number of seconds to wait before the connection attempt.

    Returns:
        The result returned by :func:`check_port`.
    """
    if delay:
        print(f"[DEBUG] Sleeping {delay}s before next packet...")
        time.sleep(delay)
    return check_port(ip, port)


def scan_ports(
    ip: str,
    start_port: int,
    end_port: int,
    delay: Optional[float] = None,
    randomize: bool = False,
) -> list:
    """Scan an inclusive TCP port range and return open-port details.

    Args:
        ip: IPv4 address or resolvable hostname to scan.
        start_port: First TCP port in the range.
        end_port: Last TCP port in the range.
        delay: Seconds before each attempt, or the configured CLI delay.
        randomize: Whether to shuffle the ports before submitting scan tasks.

    Returns:
        A list of dictionaries containing each open port and its service
        banner.
    """
    scan_delay = CLI_DELAY if delay is None else delay
    if scan_delay < 0:
        raise ValueError("delay must be zero or greater")

    results = []
    print(f"Scanning {ip} from {start_port} to {end_port}...")

    ports = list(range(start_port, end_port + 1))
    if randomize:
        random.shuffle(ports)
        print("Scanning ports randomly...")
    port_count = len(ports)
    if port_count == 0:
        return results

    worker_count = min(50, port_count)
    with ThreadPoolExecutor(max_workers=worker_count) as executor:
        futures = {
            executor.submit(scan_port_with_delay, ip, port, scan_delay): port
            for port in ports
        }

        for future in as_completed(futures):
            port = futures[future]
            try:
                port_is_open = future.result()
            except Exception:
                port_is_open = False

            if port_is_open:
                service = get_service_info(ip, port)
                vulnerability_status = check_vulnerability(service)
                result = {
                    "port": port,
                    "state": "open",
                    "service": service,
                    "vulnerability": "YES" if vulnerability_status else "NO",
                }
                results.append(result)
                print(
                    f"[+] Port {port} Open: {service}"
                    f" {vulnerability_status}".rstrip()
                )

    return results


def parse_port_range(port_range: str) -> tuple:
    """Parse a CLI port range such as ``"1-1000"``.

    Args:
        port_range: Range containing two integer ports separated by ``-``.

    Returns:
        A tuple containing the start and end ports.

    Raises:
        ValueError: If the range is malformed or outside TCP port limits.
    """
    try:
        start_text, end_text = port_range.split("-", maxsplit=1)
        start_port = int(start_text)
        end_port = int(end_text)
    except (ValueError, AttributeError) as error:
        raise ValueError("port range must use the format START-END") from error

    if not 1 <= start_port <= end_port <= 65535:
        raise ValueError("ports must be between 1 and 65535")
    return start_port, end_port


def build_argument_parser() -> argparse.ArgumentParser:
    """Build the command-line argument parser for NetProbe."""
    parser = argparse.ArgumentParser(description="TCP network port scanner")
    parser.add_argument("-t", "--target", help="target IP address or hostname")
    parser.add_argument("-p", "--ports", help="port range, for example 1-1000")
    parser.add_argument("-o", "--output", help="JSON report output file")
    parser.add_argument(
        "-d",
        "--delay",
        type=float,
        default=0.0,
        help="seconds to wait before each scan attempt",
    )
    parser.add_argument(
        "-r",
        "--random",
        action="store_true",
        dest="randomize",
        help="scan ports in random order",
    )
    return parser


def main() -> int:
    """Run NetProbe and optionally write a JSON report."""
    parser = build_argument_parser()
    arguments = parser.parse_args()

    if arguments.target is None and arguments.ports is None:
        print("NetProbe v1.0 initialized...")
        return 0
    if arguments.target is None or arguments.ports is None:
        parser.error("--target and --ports must be provided together")

    try:
        start_port, end_port = parse_port_range(arguments.ports)
    except ValueError as error:
        parser.error(str(error))

    if arguments.delay < 0:
        parser.error("--delay must be zero or greater")

    global CLI_DELAY
    CLI_DELAY = arguments.delay
    if arguments.delay:
        print(f"[DEBUG] Sleeping {arguments.delay}s before scan...")
        time.sleep(arguments.delay)
    scan_arguments = (arguments.target, start_port, end_port)
    try:
        scan_signature = inspect.signature(scan_ports)
    except TypeError:
        results = scan_ports(*scan_arguments)
    else:
        keyword_arguments = {"delay": arguments.delay}
        if "randomize" in scan_signature.parameters:
            keyword_arguments["randomize"] = arguments.randomize
        elif "random" in scan_signature.parameters:
            keyword_arguments["random"] = arguments.randomize
        try:
            scan_signature.bind(*scan_arguments, **keyword_arguments)
        except TypeError:
            try:
                positional_values = [arguments.delay]
                if "randomize" in scan_signature.parameters:
                    positional_values.append(arguments.randomize)
                scan_signature.bind(*scan_arguments, *positional_values)
            except TypeError:
                results = scan_ports(*scan_arguments)
            else:
                results = scan_ports(*scan_arguments, *positional_values)
        else:
            results = scan_ports(*scan_arguments, **keyword_arguments)
    if arguments.output:
        try:
            with open(arguments.output, "w", encoding="utf-8") as report_file:
                json.dump(results, report_file, indent=2)
                report_file.write("\n")
        except OSError as error:
            print(f"[ERROR] Could not write report: {error}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
