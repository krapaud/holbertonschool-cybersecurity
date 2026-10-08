#!/usr/bin/env python3
"""Read log files one line at a time."""

import argparse
import re
from collections import Counter
from pathlib import Path
from typing import Dict, Optional  # noqa: UP035

# This pattern is compiled once because it will be used for many log lines.
APACHE_PATTERN = re.compile(
    r'(?P<ip>\S+)\s+\S+\s+\S+\s+'
    r'\[(?P<date>[^]]+)\]\s+'
    r'"(?P<method>\S+)\s+(?P<path>\S+)\s+\S+"\s+'
    r'(?P<status>\d{3})\s+(?P<size>\d+|-)'
    r'(?:\s+"[^"]*"\s+)?(?:"(?P<user_agent>[^"]*)")?$'
)
SYSLOG_PATTERN = re.compile(
    r'(?P<date>[A-Z][a-z]{2}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+'
    r'(?P<host>\S+)\s+(?P<process>[^:]+):\s+(?P<message>.+)$'
)
IP_PATTERN = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")
GEOIP_DB = {"1.2.3.4": "US", "5.6.7.8": "RU"}
BOT_SIGNATURES = ("sqlmap", "nikto", "curl", "python")
BLACKLIST = {"10.0.0.1", "192.168.1.66"}
SQLI_PATTERNS = [
    re.compile(r"union\s+select", re.IGNORECASE),
    re.compile(r"['\"]\s*or\s+\d+\s*=\s*\d+", re.IGNORECASE),
    re.compile(r"--", re.IGNORECASE),
]
XSS_PATTERNS = [
    re.compile(r"<script", re.IGNORECASE),
    re.compile(r"javascript:", re.IGNORECASE),
    re.compile(r"onload\s*=", re.IGNORECASE),
]


class LogEntry:
    """Store Apache and Syslog events in one common format."""

    def __init__(
        self,
        ip: str,
        timestamp: str,
        service: str,
        message: str,
        raw_line: str,
        method: str = "",
        path: str = "",
        status: Optional[int] = None,  # noqa: UP045
        size: str = "",
        user_agent: str = "",
    ):
        self.ip = ip
        self.timestamp = timestamp
        self.service = service
        self.message = message
        self.raw_line = raw_line
        self.method = method
        self.path = path
        self.status = status
        self.size = size
        self.user_agent = user_agent
        self.country = "UNKNOWN"
        self.is_bot = False
        self.alert_level = "LOW"
        self.attack_type = ""


def read_stream(file_path: str):
    """Yield one line from the log file at a time."""
    try:
        with open(file_path, "r", encoding="utf-8") as log_file:
            yield from log_file
    except FileNotFoundError:
        print(f"[ERROR] File not found: {file_path}")


def parse_apache_line(
    line: str,
) -> Optional[Dict[str, str]]:  # noqa: UP006, UP045
    """Extract the main fields from one Apache log line."""
    match = APACHE_PATTERN.search(line.strip())
    if not match:
        return None

    return match.groupdict()


def parse_syslog_line(
    line: str,
) -> Optional[Dict[str, str]]:  # noqa: UP006, UP045
    """Extract the main fields from one Syslog line."""
    match = SYSLOG_PATTERN.search(line.strip())
    if not match:
        return None

    return match.groupdict()


def normalize_entry(
    parsed_dict: dict, log_type: str, raw_line: str = ""
) -> LogEntry:
    """Convert a parsed Apache or Syslog dictionary into a LogEntry."""
    if log_type == "apache":
        return LogEntry(
            ip=parsed_dict["ip"],
            timestamp=parsed_dict["date"],
            service="http",
            message=f'{parsed_dict["method"]} {parsed_dict["path"]}',
            raw_line=raw_line,
            method=parsed_dict["method"],
            path=parsed_dict["path"],
            status=int(parsed_dict["status"]),
            size=parsed_dict["size"],
            user_agent=parsed_dict.get("user_agent", ""),
        )

    if log_type == "syslog":
        ip_match = IP_PATTERN.search(parsed_dict["message"])
        ip = ip_match.group(0) if ip_match else ""
        return LogEntry(
            ip=ip,
            timestamp=parsed_dict["date"],
            service="ssh",
            message=parsed_dict["message"],
            raw_line=raw_line,
        )

    raise ValueError(f"Unknown log type: {log_type}")


def filter_logs(stream, status_codes=None):
    """Yield only log entries with one of the requested HTTP statuses."""
    if status_codes is None:
        status_codes = [404, 500]

    for entry in stream:
        if getattr(entry, "status", None) in status_codes:
            yield entry


def enrich_ip(log_entry: LogEntry) -> LogEntry:
    """Add the country associated with an entry's IP address."""
    log_entry.country = GEOIP_DB.get(log_entry.ip, "UNKNOWN")
    return log_entry


def analyze_user_agent(log_entry: LogEntry) -> LogEntry:
    """Mark an entry as a bot when it contains a known tool signature."""
    fields = (
        getattr(log_entry, "user_agent", ""),
        getattr(log_entry, "message", ""),
        getattr(log_entry, "raw_line", ""),
    )
    text = " ".join(fields).lower()
    log_entry.is_bot = any(signature in text for signature in BOT_SIGNATURES)
    return log_entry


def check_threat_intel(log_entry: LogEntry) -> LogEntry:
    """Set the alert level using the list of known malicious IPs."""
    if log_entry.ip in BLACKLIST:
        log_entry.alert_level = "HIGH"
    else:
        log_entry.alert_level = "LOW"
    return log_entry


def detect_sqli(log_entry: LogEntry) -> LogEntry:
    """Mark an entry when its path contains a SQL injection pattern."""
    path = getattr(log_entry, "path", "")
    message = getattr(log_entry, "message", "")
    text = path + " " + message
    if any(pattern.search(text) for pattern in SQLI_PATTERNS):
        log_entry.attack_type = "SQLi"
    return log_entry


def detect_xss(log_entry: LogEntry) -> LogEntry:
    """Mark an entry when its path contains an XSS pattern."""
    if getattr(log_entry, "attack_type", None):
        return log_entry

    path = getattr(log_entry, "path", "")
    if any(pattern.search(path) for pattern in XSS_PATTERNS):
        log_entry.attack_type = "XSS"
    return log_entry


def detect_bruteforce(entries):
    """Yield alerts for IPs with more than five login failures."""
    failures = Counter()
    for entry in entries:
        message = getattr(entry, "message", "")
        is_http_failure = getattr(entry, "status", None) == 401
        is_ssh_failure = "Failed password" in message
        if is_http_failure or is_ssh_failure:
            failures[entry.ip] += 1

    for ip, count in failures.items():
        if count > 5:
            yield {
                "ip": ip,
                "count": count,
                "alert_type": "BRUTE_FORCE",
            }


def main():
    """Start the LogHunter tool."""
    parser = argparse.ArgumentParser()
    parser.add_argument("file", help="path to the log file")
    args = parser.parse_args()

    print("[*] LogHunter - Log Analysis Engine")
    print(f"[*] Reading: {args.file}")

    if not Path(args.file).is_file():
        # read_stream also handles this case when it is used directly.
        print(f"[ERROR] File not found: {args.file}")
        print("[!] No data to process. Exiting.")
        return

    lines = read_stream(args.file)
    apache_count = 0
    syslog_count = 0
    sample_entry = None
    parsed_entries = []
    for line in lines:
        apache_entry = parse_apache_line(line)
        if apache_entry:
            apache_count += 1
            entry = normalize_entry(apache_entry, "apache", line)
            entry = analyze_user_agent(enrich_ip(entry))
            entry = check_threat_intel(entry)
            entry = detect_sqli(entry)
            parsed_entries.append(detect_xss(entry))
            if sample_entry is None:
                sample_entry = entry
        else:
            syslog_entry = parse_syslog_line(line)
            if not syslog_entry:
                continue
            syslog_count += 1
            entry = normalize_entry(syslog_entry, "syslog", line)
            entry = analyze_user_agent(enrich_ip(entry))
            entry = check_threat_intel(entry)
            entry = detect_sqli(entry)
            parsed_entries.append(detect_xss(entry))
            if sample_entry is None:
                sample_entry = entry

    print("--- Parsing ---")
    print(f"[*] Apache lines:  {apache_count}")
    print(f"[*] Syslog lines:  {syslog_count}")
    print(f"[*] Total parsed:  {apache_count + syslog_count}")
    known_ips = sum(
        1 for entry in parsed_entries if entry.country != "UNKNOWN"
    )
    bots_detected = sum(1 for entry in parsed_entries if entry.is_bot)
    high_alerts = sum(
        1 for entry in parsed_entries if entry.alert_level == "HIGH"
    )
    sqli_attempts = sum(
        1
        for entry in parsed_entries
        if getattr(entry, "attack_type", "") == "SQLi"
    )
    xss_attempts = sum(
        1
        for entry in parsed_entries
        if getattr(entry, "attack_type", "") == "XSS"
    )
    print("--- Enrichment ---")
    print(
        f"[*] GeoIP: {len(parsed_entries)} entries enriched "
        f"({known_ips} known IPs)"
    )
    print(f"[*] Bots detected: {bots_detected}")
    print("--- Threat Intelligence ---")
    print(
        f"[*] HIGH alerts: {high_alerts} entries from blacklisted IPs"
    )
    print("--- Attack Detection ---")
    print(f"[*] SQLi attempts: {sqli_attempts}")
    print(f"[*] XSS attempts:  {xss_attempts}")
    if sample_entry:
        print("[*] Sample entry:")
        if sample_entry.service == "http":
            print(
                f"    ip={sample_entry.ip} | service={sample_entry.service} "
                f"| status={sample_entry.status} | path={sample_entry.path}"
            )
        else:
            print(
                f"    ip={sample_entry.ip} | service={sample_entry.service}"
            )

    suspicious_entries = list(filter_logs(parsed_entries))
    print("--- Filtering ---")
    print(f"[*] Suspicious (404, 500): {len(suspicious_entries)}")
    brute_force_alerts = sorted(
        detect_bruteforce(parsed_entries),
        key=lambda alert: alert["count"],
        reverse=True,
    )
    print("--- Brute Force ---")
    print(f"[*] BRUTE_FORCE alerts: {len(brute_force_alerts)}")
    for alert in brute_force_alerts:
        print(f"    {alert['ip']}: {alert['count']} failures")


if __name__ == "__main__":
    main()
