#!/usr/bin/env python3
"""Data models used by the IntelBroker application."""

from dataclasses import dataclass, field
from typing import Any, Dict, List


@dataclass
class TargetDossier:
    """Hold API and Nmap results collected for one target IP."""

    ip: str = ""
    vt_data: Dict[str, Any] = field(default_factory=dict)
    shodan_data: Dict[str, Any] = field(default_factory=dict)
    abuse_data: Dict[str, Any] = field(default_factory=dict)
    nmap_ports: List[int] = field(default_factory=list)
