# PySniffer

[![Python 3.8+][python-badge]][python-home]
[![Scapy][scapy-badge]][scapy-home]

PySniffer is a command-line network sniffer written in Python with Scapy. It
captures packets on a selected interface, filters traffic, identifies TCP,
UDP, and ICMP packets, searches raw payloads for a string, and can save
captured traffic to a PCAP file.

Use it only on networks and interfaces you are authorized to monitor.
Live packet capture requires root privileges on Linux and macOS.

## Features

- Select a network interface and a Berkeley Packet Filter (BPF) expression.
- Display source and destination details for TCP, UDP, and ICMP packets.
- Search `Raw` payloads and print an alert when text matches.
- Save captured packets to a PCAP file.
- Print packet counts by protocol when capture stops.
- Process packets in a worker thread using a queue.
- Show a hexadecimal dump with verbose mode.

## Installation

Create and activate a virtual environment, then install the project
dependency:

```bash
python3 -m venv venv
source venv/bin/activate
python -m pip install -r requirements.txt
```

The dependency file installs Scapy. Run the tool with root privileges so
Scapy can capture packets from the network interface.

## Usage

Start capturing on the default interface:

```bash
sudo ./venv/bin/python sniffer.py
```

Choose an interface and capture only HTTP traffic:

```bash
sudo ./venv/bin/python sniffer.py --interface eth0 --filter "tcp port 80"
```

Search TCP payloads for a string:

```bash
sudo ./venv/bin/python sniffer.py --interface eth0 --filter tcp \
  --search "password="
```

Save packets to a PCAP file and print hexadecimal dumps:

```bash
sudo ./venv/bin/python sniffer.py --interface eth0 \
  --write traffic.pcap --verbose
```

Press Ctrl+C to stop capture. PySniffer drains its packet queue, closes the
PCAP writer, and prints the protocol counts.

### Command-line options

| Option | Description |
| --- | --- |
| `-i`, `--interface` | Network interface to capture on. |
| `-f`, `--filter` | BPF expression, such as `icmp` or `tcp port 80`. |
| `-s`, `--search` | Text to find in Scapy `Raw` payloads. |
| `--write` | PCAP file to append captured packets to. |
| `-v`, `--verbose` | Print a hexadecimal dump for each packet. |

Example output:

```text
[TCP] 192.168.1.5:49812 -> 1.1.1.1:80 | Flags: S
[ALERT] Payload Match found!
[INFO] Stopping capture...
[STATS] Packet counts:
TCP: 1
UDP: 0
ICMP: 0
OTHER: 0
```

## Architecture

Scapy's capture callback acts as the producer: it places each packet in a
thread-safe `Queue` and returns quickly. A separate processor thread consumes
the queue and handles protocol parsing, payload searches, PCAP writing,
statistics, and console output. A stop marker is added after capture ends;
the worker processes the remaining packets before the file closes and the
statistics are displayed.

`Sniffer` manages capture and the worker. `TCPProcessor`, `UDPProcessor`, and
`ICMPProcessor` format protocol-specific output through the `PacketProcessor`
interface.

## Tests

Run the unit test from this directory. It constructs a Scapy packet locally
and does not capture network traffic:

```bash
./venv/bin/python -m unittest -v tests.py
```

[python-badge]: https://img.shields.io/badge/Python-3.8%2B-blue
[python-home]: https://www.python.org/
[scapy-badge]: https://img.shields.io/badge/Scapy-required-orange
[scapy-home]: https://scapy.net/
