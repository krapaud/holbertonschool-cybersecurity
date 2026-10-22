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


def main() -> None:
    """Display the NetProbe initialization message."""
    print("NetProbe v1.0 initialized...")


if __name__ == "__main__":
    main()
