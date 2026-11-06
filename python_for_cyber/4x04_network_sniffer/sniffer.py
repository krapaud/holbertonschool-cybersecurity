#!/usr/bin/env python3
"""Entry point for the PySniffer network capture project."""

import os

from scapy.all import sniff
from scapy.error import Scapy_Exception
from scapy.packet import Packet


def packet_handler(packet: Packet) -> None:
    """Print a one-line summary for each captured Scapy packet."""
    print(packet.summary())


def main() -> None:
    """Capture five packets and print summaries when run with root access."""
    if os.geteuid() != 0:
        print("[ERROR] Run this script with sudo to capture packets.")
        return

    try:
        sniff(count=5, prn=packet_handler)
    except (OSError, Scapy_Exception) as error:
        print(f"[ERROR] Packet capture failed: {error}")


if __name__ == "__main__":
    main()
