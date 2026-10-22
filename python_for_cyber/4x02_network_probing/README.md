# NetProbe

NetProbe is a Python network probing tool developed for the Holberton School
cybersecurity course.

## Environment setup

Create and activate the project virtual environment:

```bash
python3 -m venv venv
source venv/bin/activate
```

No third-party dependency is currently required. The project will use Python's
standard `socket` library for authorized local network probing.

## Usage

```bash
./net_probe.py
```

Expected output:

```text
NetProbe v1.0 initialized...
```

Only scan `localhost`, a test container, or another target for which explicit
authorization has been obtained.
