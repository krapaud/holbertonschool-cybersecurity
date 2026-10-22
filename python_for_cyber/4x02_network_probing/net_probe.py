#!/usr/bin/env python3
"""Provide basic TCP port probing for the NetProbe tool."""

from concurrent.futures import ThreadPoolExecutor, as_completed
import socket

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


def scan_ports(ip: str, start_port: int, end_port: int) -> list:
    """Scan an inclusive TCP port range and return open-port details.

    Args:
        ip: IPv4 address or resolvable hostname to scan.
        start_port: First TCP port in the range.
        end_port: Last TCP port in the range.

    Returns:
        A list of dictionaries containing each open port and its service
        banner.
    """
    results = []
    print(f"Scanning {ip} from {start_port} to {end_port}...")

    ports = range(start_port, end_port + 1)
    port_count = len(ports)
    if port_count == 0:
        return results

    worker_count = min(50, port_count)
    with ThreadPoolExecutor(max_workers=worker_count) as executor:
        futures = {
            executor.submit(check_port, ip, port): port for port in ports
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
                result = {"port": port, "service": service}
                results.append(result)
                print(
                    f"[+] Port {port} Open: {service}"
                    f" {vulnerability_status}".rstrip()
                )

    return results


def main() -> None:
    """Display the NetProbe initialization message."""
    print("NetProbe v1.0 initialized...")


if __name__ == "__main__":
    main()
