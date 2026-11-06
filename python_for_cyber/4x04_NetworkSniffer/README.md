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

Run the starter script:

```bash
./py_sniffer.py
```

Expected output:

```text
PySniffer v1.0 initialized...
```

## Exercise 0: project environment

Prepare the workspace by creating the virtual environment, installing Scapy,
and making sure `py_sniffer.py` is executable. The script should start with
the required Python 3 shebang and provide the initialization message above.

## Project roadmap

- Capture packets from a selected network interface with Scapy.
- Filter captured packets with a BPF expression.
- Display source, destination, protocol, and relevant transport details.
- Save selected packets to a `.pcap` file.
- Organize capture and packet processing with `PacketHandler` and
  `SnifferEngine` classes, then test the code without requiring live traffic.
