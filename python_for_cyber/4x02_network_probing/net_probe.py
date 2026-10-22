#!/usr/bin/env python3
"""Provide basic TCP port probing for the NetProbe tool."""

import socket


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


def main() -> None:
    """Display the NetProbe initialization message."""
    print("NetProbe v1.0 initialized...")


if __name__ == "__main__":
    main()
