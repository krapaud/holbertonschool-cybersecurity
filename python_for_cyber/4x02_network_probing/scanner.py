#!/usr/bin/env python3
"""Implement NetProbe's TCP and UDP network probing operations."""

from concurrent.futures import ThreadPoolExecutor, as_completed
import socket
from typing import Dict, List, Optional

from utils import build_port_order, wait_before_scan

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
SOURCE_IP: Optional[str] = None


def configure_scanner(delay: float, source_ip: Optional[str]) -> None:
    """Set the default delay and local source address for scanner sockets.

    Args:
        delay: Default number of seconds to wait before each port attempt.
        source_ip: Local IPv4 address to bind, or ``None`` for system routing.
    """
    global CLI_DELAY, SOURCE_IP
    CLI_DELAY = delay
    SOURCE_IP = source_ip


def bind_source_interface(connection: socket.socket) -> None:
    """Bind a socket to the configured local interface when selected.

    Args:
        connection: Socket to bind before sending or connecting.
    """
    if SOURCE_IP is not None:
        connection.bind((SOURCE_IP, 0))


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
        bind_source_interface(connection)
        connection.connect((ip, port))
        return True
    except OSError:
        return False
    finally:
        connection.close()


def scan_udp(ip: str, port: int) -> bool:
    """Probe a UDP port and report whether it is open or filtered.

    Args:
        ip: IPv4 address or resolvable hostname to probe.
        port: UDP port number to probe.

    Returns:
        ``True`` when a response arrives or the port remains open/filtered
        after a timeout. A socket error such as ICMP port unreachable returns
        ``False``.
    """
    connection = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    connection.settimeout(1.0)

    try:
        bind_source_interface(connection)
        connection.sendto(b"", (ip, port))
        try:
            connection.recvfrom(1024)
            return True
        except socket.timeout:
            return True
    except OSError:
        return False
    finally:
        connection.close()


def resolve_hostname(ip: str) -> str:
    """Return the reverse-DNS hostname for an IP address when available.

    Args:
        ip: IPv4 address to resolve.

    Returns:
        The primary hostname, or ``"Unknown"`` when no PTR record is found.
    """
    try:
        hostname, _, _ = socket.gethostbyaddr(ip)
        return hostname
    except (socket.herror, socket.gaierror, OSError):
        return "Unknown"


def ping_sweep(subnet: str) -> List[str]:
    """Return hosts in a /24 subnet accepting TCP connections on port 80.

    Args:
        subnet: First three IPv4 octets, for example ``"192.168.1"``.

    Returns:
        Responsive host IP addresses from ``.1`` through ``.254``.
    """
    live_hosts = []
    for host_number in range(1, 255):
        ip_address = f"{subnet}.{host_number}"
        if check_port(ip_address, 80):
            live_hosts.append(ip_address)
    return live_hosts


def get_banner(ip: str, port: int) -> str:
    """Return a service banner or the HTTP Server header from ``ip:port``.

    Args:
        ip: IPv4 address or resolvable hostname to contact.
        port: TCP port where the service is listening.

    Returns:
        The service banner, HTTP Server value, or ``"Unknown"``.
    """
    connection = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    connection.settimeout(1.0)

    try:
        bind_source_interface(connection)
        connection.connect((ip, port))
        if port == 80:
            request = (
                f"GET / HTTP/1.1\r\nHost: {ip}\r\n"
                "Connection: close\r\n\r\n"
            )
            connection.sendall(request.encode("ascii"))
        else:
            connection.sendall(b"HEAD / HTTP/1.0\r\n\r\n")
        response = connection.recv(1024)
        if not response:
            return "Unknown"
        decoded_response = response.decode("utf-8", errors="replace")
        if port == 80:
            for header_line in decoded_response.splitlines():
                header_name, separator, header_value = (
                    header_line.partition(":")
                )
                if separator and header_name.strip().lower() == "server":
                    return header_value.strip() or "Unknown"
            return "Unknown"
        return decoded_response.strip()
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
        The banner, HTTP Server value, or guessed service name.
    """
    banner = get_banner(ip, port)
    if banner != "Unknown" and banner:
        if port == 80:
            return f"HTTP ({banner})"
        return banner

    guessed_service = guess_service(port)
    if guessed_service == "Unknown":
        return "Unknown"
    return f"{guessed_service} (Guessed)"


def check_vulnerability(banner: str) -> str:
    """Return a vulnerability marker when a banner matches a known signature.

    Args:
        banner: Service banner to compare with known vulnerable signatures.

    Returns:
        ``"[VULNERABLE]"`` when a known signature is found, otherwise empty.
    """
    normalized_banner = banner.lower()
    for signature in KNOWN_BAD_SIGNATURES:
        if signature.lower() in normalized_banner:
            return "[VULNERABLE]"
    return ""


def scan_port_with_delay(ip: str, port: int, delay: float) -> bool:
    """Wait if configured, then check whether one TCP port is open.

    Args:
        ip: IPv4 address or resolvable hostname to scan.
        port: TCP port to probe.
        delay: Number of seconds to wait before the connection attempt.

    Returns:
        The result returned by :func:`check_port`.
    """
    wait_before_scan(
        delay,
        f"[DEBUG] Sleeping {delay}s before next packet...",
    )
    return check_port(ip, port)


def scan_ports(
    ip: str,
    start_port: int,
    end_port: int,
    delay: Optional[float] = None,
    randomize: bool = False,
) -> List[Dict[str, object]]:
    """Scan an inclusive TCP port range and return open-port details.

    Args:
        ip: IPv4 address or resolvable hostname to scan.
        start_port: First TCP port in the range.
        end_port: Last TCP port in the range.
        delay: Seconds to wait before each attempt, or the configured default.
        randomize: Whether to shuffle the ports before submitting scan tasks.

    Returns:
        A list of dictionaries describing open ports and detected services.
    """
    scan_delay = CLI_DELAY if delay is None else delay
    if scan_delay < 0:
        raise ValueError("delay must be zero or greater")

    print(f"Scanning {ip} from {start_port} to {end_port}...")
    ports = build_port_order(start_port, end_port, randomize)
    if not ports:
        return []

    results = []
    worker_count = min(50, len(ports))
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
                vulnerable = check_vulnerability(service)
                results.append(
                    {
                        "port": port,
                        "state": "open",
                        "service": service,
                        "vulnerability": "YES" if vulnerable else "NO",
                    }
                )
                print(
                    f"[+] Port {port} Open: {service} {vulnerable}".rstrip()
                )
    return results
