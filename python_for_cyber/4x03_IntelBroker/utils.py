#!/usr/bin/env python3
"""Cache and report file helpers for IntelBroker."""

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

if __package__:
    from .models import TargetDossier
else:
    from models import TargetDossier


CACHE_FILE = Path(__file__).with_name("cache.json")
CACHE_TTL = timedelta(hours=1)


def load_cached_intel(ip: str) -> Optional[List[Dict[str, Any]]]:
    """Return cached API data if its timestamp is less than one hour old."""
    try:
        cache = json.loads(CACHE_FILE.read_text(encoding="utf-8"))
        entry = cache.get(ip)
        if not isinstance(entry, dict):
            return None
        timestamp = datetime.fromisoformat(entry["timestamp"])
        if timestamp.tzinfo is None:
            timestamp = timestamp.replace(tzinfo=timezone.utc)
        cached_data = entry["data"]
    except FileNotFoundError:
        return None
    except (OSError, ValueError, KeyError, TypeError):
        print("[WARNING] Cache file is unreadable; querying the APIs.")
        return None

    age = datetime.now(timezone.utc) - timestamp
    if age < timedelta(0) or age >= CACHE_TTL:
        return None
    if (not isinstance(cached_data, list) or len(cached_data) != 3 or
            not all(isinstance(item, dict) for item in cached_data)):
        return None
    return cached_data


def save_cached_intel(ip: str, data: List[Dict[str, Any]]) -> None:
    """Persist successful API results and their UTC timestamp."""
    cache: Dict[str, Any] = {}
    try:
        if CACHE_FILE.exists():
            loaded_cache = json.loads(CACHE_FILE.read_text(encoding="utf-8"))
            if isinstance(loaded_cache, dict):
                cache = loaded_cache
        cache[ip] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "data": data,
        }
        CACHE_FILE.write_text(
            json.dumps(cache, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    except (OSError, TypeError, ValueError) as error:
        print(f"[WARNING] Could not save API cache: {error}")


def save_report(dossier: TargetDossier, output_path: str) -> None:
    """Write a timestamped JSON report for a target dossier."""
    report = {
        "target": dossier.ip,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "intelligence": {
            "virustotal": dossier.vt_data,
            "shodan": dossier.shodan_data,
            "abuseipdb": dossier.abuse_data,
            "nmap": {"open_ports": dossier.nmap_ports},
        },
    }
    try:
        Path(output_path).write_text(
            json.dumps(report, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    except OSError as error:
        raise RuntimeError(
            f"Could not write JSON report to {output_path}: {error}"
        ) from error
