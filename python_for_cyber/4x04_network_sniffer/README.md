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

Start a continuous capture with root privileges. Press Ctrl+C to stop it:

```bash
sudo ./sniffer.py
```

Choose a network interface with `-i` and apply a BPF filter with `-f`:

```bash
sudo ./sniffer.py --interface eth0 --filter "icmp"
```

Save captured packets to a PCAP file with `--write`:

```bash
sudo ./sniffer.py --filter "icmp" --write output.pcap
```

Add a hexadecimal dump after each packet line with `-v`:

```bash
sudo ./sniffer.py --verbose
```

For IPv4 packets, the handler identifies TCP, UDP, or ICMP and prints the
source and destination addresses:

```text
[TCP] 192.168.1.5:49812 -> 1.1.1.1:80 | Flags: S
```

## Exercise 0: project environment

Prepare the workspace by creating the virtual environment, installing Scapy,
and making sure `sniffer.py` is executable. The script should start with the
required Python 3 shebang and install Scapy in the active virtual environment.

## Exercise 1: capture packet summaries

The entry point calls Scapy's `sniff()` with `packet_handler` as the
`prn` callback and keeps capturing until Ctrl+C. Run it with `sudo` because
packet capture requires root privileges.

## Project roadmap

- Capture packets from a selected network interface with Scapy.
- Filter captured packets with a BPF expression.
- Display source, destination, protocol, and relevant transport details.
- Save selected packets to a `.pcap` file.
- Organize capture and packet processing with `PacketHandler` and
  `SnifferEngine` classes, then test the code without requiring live traffic.

## Exercise 2: identify protocols

The packet handler checks for an IPv4 layer, then identifies TCP, UDP, or
ICMP. It prints the protocol name and the source and destination IP addresses.
Packets without IPv4 or without one of these protocols are ignored.

## Exercise 3: show TCP details

TCP packets include the source and destination ports and their flags in the
output. UDP and ICMP packets keep the address-only format.

## Exercise 4: continuous capture

The sniffer runs until interrupted with Ctrl+C, then prints a stopping message.

## Exercise 5: select interface and BPF filter

The `-i` or `--interface` option selects the capture interface. The `-f` or
`--filter` option passes a BPF expression to Scapy, such as `icmp`.

## Exercise 6: write packets to PCAP

The optional `--write` argument saves captured packets to the given PCAP file.
One writer stays open for the capture and appends packets as they arrive.

## Exercise 7: verbose packet output

Use `-v` or `--verbose` to print Scapy's hexadecimal dump after each recognized
packet summary. Without this option, the regular output is unchanged.
