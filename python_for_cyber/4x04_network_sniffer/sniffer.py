#!/usr/bin/env python3
"""Point d’entrée du projet PySniffer pour capturer le trafic réseau."""

import argparse
import os
from typing import Any, Optional, Tuple

import scapy.all as scapy_all
from scapy.all import sniff


# Résout Scapy dynamiquement pour rester compatible avec les mocks.
hexdump = getattr(scapy_all, "hexdump", None)


class PacketProcessor:
    """Définit l’interface des processeurs de protocoles réseau."""

    protocol_layer: Any = None
    protocol_name = ""

    def process(self, packet: Any) -> str:
        """Retourne une description du paquet selon son protocole.

        Args:
            packet: paquet Scapy à décrire.

        Returns:
            Description textuelle affichée pour le paquet.

        Raises:
            NotImplementedError: si une sous-classe ne définit pas le format.
        """
        raise NotImplementedError("A protocol processor must format packets.")

    def _ip_addresses(self, packet: Any) -> Tuple[str, str]:
        """Récupère les adresses IP source et destination du paquet.

        Args:
            packet: paquet Scapy contenant une couche IP.

        Returns:
            Couple (adresse source, adresse destination).
        """
        ip_layer = getattr(scapy_all, "IP", "IP")
        try:
            ip_packet = packet[ip_layer]
        except (KeyError, IndexError, TypeError, AttributeError):
            ip_packet = packet
        return (
            str(getattr(ip_packet, "src", "?")),
            str(getattr(ip_packet, "dst", "?")),
        )

    def _protocol_packet(self, packet: Any) -> Any:
        """Récupère la couche de protocole ou utilise le paquet lui-même.

        Args:
            packet: paquet complet ou couche de protocole seule.

        Returns:
            Couche extraite, ou paquet d’origine si elle est inaccessible.
        """
        try:
            return packet[self.protocol_layer]
        except (KeyError, IndexError, TypeError, AttributeError):
            return packet


class TCPProcessor(PacketProcessor):
    """Formate les paquets TCP avec ports et flags."""

    protocol_layer = getattr(scapy_all, "TCP", "TCP")
    protocol_name = "TCP"

    def process(self, packet: Any) -> str:
        """Retourne les adresses, ports et flags TCP du paquet.

        Args:
            packet: paquet Scapy contenant les couches IP et TCP.

        Returns:
            Ligne résumant le paquet TCP.
        """
        source_ip, destination_ip = self._ip_addresses(packet)
        tcp_packet = self._protocol_packet(packet)
        source_port = getattr(
            tcp_packet, "sport", getattr(packet, "sport", "?")
        )
        destination_port = getattr(
            tcp_packet, "dport", getattr(packet, "dport", "?")
        )
        tcp_flags = getattr(
            tcp_packet, "flags", getattr(packet, "flags", "?")
        )
        summary = (
            f"[TCP] {source_ip}:{source_port} -> "
            f"{destination_ip}:{destination_port} | Flags: {tcp_flags}"
        )
        print(summary)
        return summary


class UDPProcessor(PacketProcessor):
    """Formate les paquets UDP avec leurs adresses IP."""

    protocol_layer = getattr(scapy_all, "UDP", "UDP")
    protocol_name = "UDP"

    def process(self, packet: Any) -> str:
        """Retourne les adresses source et destination du paquet UDP.

        Args:
            packet: paquet Scapy contenant les couches IP et UDP.

        Returns:
            Ligne résumant le paquet UDP.
        """
        source_ip, destination_ip = self._ip_addresses(packet)
        summary = f"[UDP] {source_ip} -> {destination_ip}"
        print(summary)
        return summary


class ICMPProcessor(PacketProcessor):
    """Formate les paquets ICMP avec leurs adresses IP."""

    protocol_layer = getattr(scapy_all, "ICMP", "ICMP")
    protocol_name = "ICMP"

    def process(self, packet: Any) -> str:
        """Retourne les adresses source et destination du paquet ICMP.

        Args:
            packet: paquet Scapy contenant les couches IP et ICMP.

        Returns:
            Ligne résumant le paquet ICMP.
        """
        source_ip, destination_ip = self._ip_addresses(packet)
        summary = f"[ICMP] {source_ip} -> {destination_ip}"
        print(summary)
        return summary


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
        self._processors = (
            TCPProcessor(),
            UDPProcessor(),
            ICMPProcessor(),
        )
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

        # La classe choisie produit le résumé du protocole détecté.
        ip_layer = getattr(scapy_all, "IP", "IP")
        packet_summary = None
        processor_printed = False
        has_layer = getattr(packet, "haslayer", None)
        if callable(has_layer) and has_layer(ip_layer):
            for processor in self._processors:
                if has_layer(processor.protocol_layer):
                    packet_summary = processor.process(packet)
                    processor_printed = True
                    break

        # Pour les autres paquets, on conserve le résumé fourni par Scapy.
        if packet_summary is None:
            summary_method = getattr(packet, "summary", None)
            packet_summary = (
                summary_method() if callable(summary_method) else str(
                    packet
                )
            )

        if not processor_printed:
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
