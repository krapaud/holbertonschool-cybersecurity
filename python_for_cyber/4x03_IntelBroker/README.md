# IntelBroker

IntelBroker is a Python cybersecurity course project about enriching an IP
address with local scan results and simulated threat-intelligence data.

## Project setup

Create and activate a virtual environment:

```bash
python3 -m venv venv
source venv/bin/activate
```

The mock API uses only Python's standard library, so no extra package is
required for this setup exercise.

## Exercise 0: start the mock API

Run the local server:

```bash
./mock_api.py
```

In another terminal, verify that it returns JSON:

```bash
curl http://localhost:5000/virustotal/8.8.8.8
```

The server simulates the VirusTotal, Shodan, and AbuseIPDB endpoints. Its
results are randomly generated for practice and are not real threat
intelligence. It listens only on `localhost:5000`.

Stop it with `Ctrl+C`.
