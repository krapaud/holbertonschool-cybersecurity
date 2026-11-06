# Python - Network Sniffer

PySniffer is a Python project for learning passive packet capture and
dissection with Scapy. The planned tool will capture traffic on a selected
interface, apply BPF filters, display packet summaries, and optionally save
packets to a PCAP file.

Only capture traffic on networks and interfaces you are authorized to
monitor. Live packet capture generally requires root privileges.

## Setup

Create and activate a virtual environment, then install the dependency:

```bash
python3 -m venv venv
source venv/bin/activate
python -m pip install -r requirements.txt
```

Start a five-packet capture with root privileges:

```bash
sudo ./sniffer.py
```

Each captured packet is printed as a one-line Scapy summary, for example:

```text
Ether / IP / TCP 192.168.1.5:54321 > 1.1.1.1:80 S
```

## Exercise 0: project environment

Prepare the workspace by creating the virtual environment, installing Scapy,
and making sure `sniffer.py` is executable. The script should start with the
required Python 3 shebang and install Scapy in the active virtual environment.

## Exercise 1: capture packet summaries

`packet_handler(packet)` prints `packet.summary()` for each captured packet.
The entry point calls Scapy's `sniff()` with `count=5` and the callback as
`prn`. Run it with `sudo` because packet capture requires root privileges.

## Project roadmap

- Capture packets from a selected network interface with Scapy.
- Filter captured packets with a BPF expression.
- Display source, destination, protocol, and relevant transport details.
- Save selected packets to a `.pcap` file.
- Organize capture and packet processing with `PacketHandler` and
  `SnifferEngine` classes, then test the code without requiring live traffic.
