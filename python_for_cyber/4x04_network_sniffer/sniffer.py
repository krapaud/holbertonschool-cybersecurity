#!/usr/bin/env python3
"""Entry point for the PySniffer network capture project."""

import os
from typing import Any

import scapy.all as scapy_all
from scapy.all import sniff


def packet_handler(packet: Any) -> None:
    """Print IP endpoints and the recognized transport protocol."""
    ip_layer = getattr(scapy_all, "IP", "IP")
    tcp_layer = getattr(scapy_all, "TCP", "TCP")
    udp_layer = getattr(scapy_all, "UDP", "UDP")
    icmp_layer = getattr(scapy_all, "ICMP", "ICMP")

    if not packet.haslayer(ip_layer):
        return

    source_ip = packet[ip_layer].src
    destination_ip = packet[ip_layer].dst
    for protocol_name, protocol_layer in (
        ("TCP", tcp_layer),
        ("UDP", udp_layer),
        ("ICMP", icmp_layer),
    ):
        if packet.haslayer(protocol_layer):
            print(f"[{protocol_name}] {source_ip} -> {destination_ip}")
            return


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
