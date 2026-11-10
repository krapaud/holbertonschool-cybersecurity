#!/usr/bin/env python3
"""Point d’entrée du projet PySniffer pour capturer le trafic réseau."""

import argparse
import os
from typing import Any

import scapy.all as scapy_all
from scapy.all import sniff


# Le writer est partagé avec le callback et reste ouvert pendant la capture.
_pcap_writer: Any = None
# Active le dump hexadécimal demandé par l’option verbose.
_verbose = False
# Résout Scapy dynamiquement pour rester compatible avec les mocks.
hexdump = getattr(scapy_all, "hexdump", None)


def packet_handler(packet: Any) -> None:
    """Enregistre un paquet et affiche ses détails de protocole.

    Args:
        packet: paquet Scapy reçu par le callback de capture.

    Returns:
        None.
    """
    # On enregistre aussi les paquets dont le protocole ne sera pas affiché.
    if _pcap_writer is not None:
        _pcap_writer.write(packet)

    # Les noms de couches en secours gardent la compatibilité avec les mocks.
    ip_layer = getattr(scapy_all, "IP", "IP")
    tcp_layer = getattr(scapy_all, "TCP", "TCP")
    udp_layer = getattr(scapy_all, "UDP", "UDP")
    icmp_layer = getattr(scapy_all, "ICMP", "ICMP")

    packet_summary = None
    has_layer = getattr(packet, "haslayer", None)
    if callable(has_layer) and has_layer(ip_layer):
        source_ip = packet[ip_layer].src
        destination_ip = packet[ip_layer].dst
        for protocol_name, protocol_layer in (
            ("TCP", tcp_layer),
            ("UDP", udp_layer),
            ("ICMP", icmp_layer),
        ):
            if has_layer(protocol_layer):
                if protocol_name == "TCP":
                    tcp_packet = packet[protocol_layer]
                    packet_summary = (
                        f"[TCP] {source_ip}:{tcp_packet.sport} -> "
                        f"{destination_ip}:{tcp_packet.dport} | "
                        f"Flags: {tcp_packet.flags}"
                    )
                else:
                    packet_summary = (
                        f"[{protocol_name}] {source_ip} -> "
                        f"{destination_ip}"
                    )
                break

    # Pour les autres paquets, on conserve le résumé fourni par Scapy.
    if packet_summary is None:
        summary_method = getattr(packet, "summary", None)
        packet_summary = summary_method() if callable(summary_method) else str(
            packet
        )

    print(packet_summary)
    dump_packet = hexdump or getattr(scapy_all, "hexdump", None)
    if _verbose and dump_packet is not None:
        dump_packet(packet)


def main() -> None:
    """Lance la capture jusqu’à son interruption ou une erreur.

    Les options CLI choisissent l’interface, le filtre BPF et le fichier PCAP.

    Returns:
        None.
    """
    parser = argparse.ArgumentParser(description="Capture network packets.")
    parser.add_argument(
        "-i", "--interface", help="Network interface to capture on."
    )
    parser.add_argument(
        "-f", "--filter", help="BPF filter expression for captured packets."
    )
    parser.add_argument(
        "--write", help="Append captured packets to a PCAP file."
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true",
        help="Print a hexadecimal dump for each packet."
    )
    arguments = parser.parse_args()
    # Le callback lit cette valeur pour décider d’afficher le dump hexadécimal.
    global _verbose
    _verbose = arguments.verbose

    # Scapy a besoin des privilèges root pour écouter sur une interface.
    if os.geteuid() != 0:
        print("[ERROR] Run this script with sudo to capture packets.")
        return

    global _pcap_writer
    try:
        # Un seul writer ouvert évite de rouvrir le PCAP à chaque paquet.
        if arguments.write:
            writer_class = getattr(scapy_all, "PcapWriter", None)
            if writer_class is None:
                raise RuntimeError("Scapy PcapWriter is unavailable.")
            _pcap_writer = writer_class(arguments.write, append=True)
        sniff(
            iface=arguments.interface,
            filter=arguments.filter,
            prn=packet_handler,
        )
    except KeyboardInterrupt:
        # Ctrl+C est une fin normale pour une capture lancée en continu.
        print("[INFO] Stopping capture...")
    except Exception as error:
        print(f"[ERROR] Packet capture failed: {error}")
    finally:
        # Ferme le PCAP même si la capture s’arrête avec Ctrl+C ou une erreur.
        if _pcap_writer is not None:
            try:
                _pcap_writer.close()
            except Exception as error:
                print(f"[ERROR] PCAP file could not be closed: {error}")
            finally:
                _pcap_writer = None


if __name__ == "__main__":
    main()
