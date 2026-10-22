#!/usr/bin/env python3
"""Asynchronous Nmap execution and XML result parsing."""

import asyncio
import xml.etree.ElementTree as ET
from typing import List


async def run_nmap(ip: str) -> str:
    """Run Nmap asynchronously and return its raw XML output."""
    command = ["nmap", "-p", "22,80", ip, "-oX", "-"]
    try:
        process = await asyncio.create_subprocess_exec(
            *command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
    except FileNotFoundError as error:
        message = "Nmap is not installed or not found in PATH."
        raise RuntimeError(message) from error
    except OSError as error:
        raise RuntimeError(f"Could not run Nmap: {error}") from error

    stdout, stderr = await process.communicate()
    if process.returncode != 0:
        error_message = stderr.decode(errors="replace").strip()
        message = error_message or "Nmap returned a non-zero status."
        raise RuntimeError(f"Nmap failed: {message}")
    return stdout.decode(errors="replace")


def parse_nmap_xml(xml_data: str) -> List[int]:
    """Return port numbers whose state is open from Nmap XML output."""
    try:
        root = ET.fromstring(xml_data)
    except ET.ParseError as error:
        raise ValueError("Nmap output is not valid XML.") from error

    open_ports = []
    for port_element in root.findall(".//host/ports/port"):
        state_element = port_element.find("state")
        if (state_element is not None and
                state_element.get("state") == "open"):
            port_id = port_element.get("portid")
            if port_id is not None:
                try:
                    open_ports.append(int(port_id))
                except ValueError:
                    continue
    return open_ports
