#!/usr/bin/env python3
"""Point d’entrée du projet PySniffer pour capturer le trafic réseau."""

import argparse
import os
from typing import Any, Optional

import scapy.all as scapy_all
from scapy.all import sniff


# Résout Scapy dynamiquement pour rester compatible avec les mocks.
hexdump = getattr(scapy_all, "hexdump", None)


class Sniffer:
    """Configure la capture, traite les paquets et gère le fichier PCAP."""

    def __init__(
        self,
        interface: Optional[str],
        filter_str: Optional[str],
        output_file: Optional[str],
    ) -> None:
        """Mémorise les paramètres qui serviront pendant la capture.

        Args:
            interface: interface réseau choisie, ou None pour
                l’interface par défaut.
            filter_str: filtre BPF à appliquer, ou None pour tout capturer.
            output_file: chemin du PCAP, ou None si l’écriture est désactivée.

        Returns:
            None.
        """
        self.interface = interface
        self.filter_str = filter_str
        self.output_file = output_file
        self.verbose = False
        # Le writer reste ouvert pour éviter de rouvrir le PCAP
        # à chaque paquet.
        self._pcap_writer: Any = None

    def start(self) -> None:
        """Lance la capture jusqu’à son interruption ou une erreur.

        Returns:
            None.
        """
        try:
            if self.output_file:
                writer_class = getattr(scapy_all, "PcapWriter", None)
                if writer_class is None:
                    raise RuntimeError("Scapy PcapWriter is unavailable.")
                self._pcap_writer = writer_class(
                    self.output_file,
                    append=True,
                )

            sniff(
                iface=self.interface,
                filter=self.filter_str,
                prn=self._process_packet,
            )
        except KeyboardInterrupt:
            # Ctrl+C est une fin normale pour une capture continue.
            print("[INFO] Stopping capture...")
        except Exception as error:
            print(f"[ERROR] Packet capture failed: {error}")
        finally:
            self._close_writer()

    def _process_packet(self, packet: Any) -> None:
        """Enregistre le paquet et affiche ses informations utiles.

        Args:
            packet: paquet Scapy transmis par le callback de capture.

        Returns:
            None.
        """
        # On enregistre aussi les paquets dont le protocole
        # ne sera pas affiché.
        if self._pcap_writer is not None:
            self._pcap_writer.write(packet)

        # Les noms de couches en secours gardent la compatibilité
        # avec les mocks.
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
            packet_summary = (
                summary_method() if callable(summary_method) else str(
                    packet
                )
            )

        print(packet_summary)
        dump_packet = hexdump or getattr(scapy_all, "hexdump", None)
        if self.verbose and dump_packet is not None:
            dump_packet(packet)

    def _close_writer(self) -> None:
        """Ferme le writer PCAP s’il a été créé.

        Returns:
            None.
        """
        if self._pcap_writer is None:
            return

        try:
            self._pcap_writer.close()
        except Exception as error:
            print(f"[ERROR] PCAP file could not be closed: {error}")
        finally:
            self._pcap_writer = None


def main() -> None:
    """Lit les options CLI et démarre le sniffer configuré.

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

    # La capture nécessite root; la classe reste testable sans privilèges.
    if os.geteuid() != 0:
        print("[ERROR] Run this script with sudo to capture packets.")
        return

    sniffer = Sniffer(
        arguments.interface,
        arguments.filter,
        arguments.write,
    )
    sniffer.verbose = arguments.verbose
    sniffer.start()


if __name__ == "__main__":
    main()
