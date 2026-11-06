#!/usr/bin/env python3
"""Entry point for the PySniffer network capture project."""

import argparse
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
            if protocol_name == "TCP":
                tcp_packet = packet[protocol_layer]
                print(
                    f"[TCP] {source_ip}:{tcp_packet.sport} -> "
                    f"{destination_ip}:{tcp_packet.dport} | "
                    f"Flags: {tcp_packet.flags}"
                )
            else:
                print(
                    f"[{protocol_name}] {source_ip} -> "
                    f"{destination_ip}"
                )
            return


def main() -> None:
    """Capture packets continuously using the selected interface and filter."""
    parser = argparse.ArgumentParser(description="Capture network packets.")
    parser.add_argument(
        "-i", "--interface", help="Network interface to capture on."
    )
    parser.add_argument(
        "-f", "--filter", help="BPF filter expression for captured packets."
    )
    arguments = parser.parse_args()

    if os.geteuid() != 0:
        print("[ERROR] Run this script with sudo to capture packets.")
        return

    try:
        sniff(
            iface=arguments.interface,
            filter=arguments.filter,
            prn=packet_handler,
        )
    except KeyboardInterrupt:
        print("[INFO] Stopping capture...")
    except Exception as error:
        print(f"[ERROR] Packet capture failed: {error}")


if __name__ == "__main__":
    main()
