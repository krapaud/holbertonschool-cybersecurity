#!/usr/bin/env python3
"""Run a local mock threat-intelligence API for IntelBroker exercises."""

import json
import random
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Any, Dict


class MockHandler(BaseHTTPRequestHandler):
    """Return simulated VirusTotal, Shodan, and AbuseIPDB JSON responses."""

    def do_GET(self) -> None:
        """Handle GET requests and return the matching API response as JSON."""
        ip_address = self.path.rstrip("/").split("/")[-1]

        if "virustotal" in self.path:
            score = random.randint(0, 10)
            data: Dict[str, Any] = {
                "ip": ip_address,
                "reputation_score": score,
                "malicious": score > 5,
            }
        elif "shodan" in self.path:
            ports = [80, 443, 22, 8080]
            data = {
                "ip": ip_address,
                "ports": random.sample(ports, k=random.randint(1, 3)),
                "os": "Linux",
                "isp": "CloudNet",
            }
        elif "abuseipdb" in self.path:
            data = {
                "ip": ip_address,
                "abuse_confidence_score": random.randint(0, 100),
                "reports": random.randint(0, 50),
            }
        else:
            data = {"error": "Unknown API"}

        response = json.dumps(data).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(response)))
        self.end_headers()
        self.wfile.write(response)


def main() -> None:
    """Start the mock API server on localhost port 5000."""
    try:
        server = HTTPServer(("localhost", 5000), MockHandler)
    except OSError as error:
        print(f"[ERROR] Could not start the mock API server: {error}.")
        return

    print("Mock API Server running on port 5000...", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nMock API Server stopped.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
