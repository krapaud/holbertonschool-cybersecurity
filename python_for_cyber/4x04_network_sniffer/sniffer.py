#!/usr/bin/env python3
"""Entry point for the PySniffer network capture project."""

import os
from typing import Any

from scapy.all import sniff


def packet_handler(packet: Any) -> None:
    """Print a one-line summary for each captured Scapy packet."""
    print(packet.summary())


def main() -> None:
    """Capture five packets and print summaries when run with root access."""
    if os.geteuid() != 0:
        print("[ERROR] Run this script with sudo to capture packets.")
        return

    try:
        sniff(count=5, prn=packet_handler)
    except Exception as error:
        print(f"[ERROR] Packet capture failed: {error}")


if __name__ == "__main__":
    main()
