#!/usr/bin/env python3
"""Tests unitaires locaux pour les processeurs de paquets PySniffer."""

import contextlib
import io
import unittest

import scapy.all as scapy_all

from sniffer import TCPProcessor

IP = getattr(scapy_all, "IP")
TCP = getattr(scapy_all, "TCP")


class TCPProcessorTests(unittest.TestCase):
    """Vérifie l’extraction des champs d’un paquet TCP Scapy."""

    def test_extracts_source_ip_and_destination_port(self) -> None:
        """Le résumé contient l’IP source et le port TCP de destination."""
        packet = (
            IP(src="1.1.1.1", dst="2.2.2.2")
            / TCP(sport=12345, dport=80, flags="S")
        )
        output = io.StringIO()

        with contextlib.redirect_stdout(output):
            summary = TCPProcessor().process(packet)

        self.assertIn("1.1.1.1", summary)
        self.assertIn(":80", summary)
        self.assertEqual(output.getvalue().strip(), summary)


if __name__ == "__main__":
    unittest.main()
