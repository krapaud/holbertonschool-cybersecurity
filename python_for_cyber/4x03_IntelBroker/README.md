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

## Exercise 1: query VirusTotal

Install the project dependencies inside the active virtual environment:

```bash
python -m pip install -r requirements.txt
```

The API client uses `aiohttp` for asynchronous HTTP requests.

With the mock API running, query it from the client:

```bash
./intel_broker.py 8.8.8.8
```

The mock reputation score is random, so the returned values can change with
each request. `query_virustotal(ip)` and `query_abuseipdb(ip)` return their
JSON objects as Python dictionaries, or an empty dictionary if a request
fails. AbuseIPDB data includes the `abuse_confidence_score` and report count.

## Exercise 5: create a target dossier

Run all three intelligence APIs for an IP address:

```bash
./intel_broker.py 8.8.8.8
```

The VirusTotal, Shodan, and AbuseIPDB requests run concurrently. The summary
also includes open TCP ports found by Nmap, which must be installed locally.

To save the complete dossier as JSON, use `-o` or `--output`:

```bash
./intel_broker.py 8.8.8.8 --output report.json
```

The report contains the target IP, a UTC timestamp, and the VirusTotal,
Shodan, AbuseIPDB, and Nmap results.

## Exercise 10: cache API results

Successful VirusTotal, Shodan, and AbuseIPDB responses are stored in
`cache.json` for one hour. Re-running the client for the same IP within that
period reuses the cached API results; expired entries are queried again.
API requests are also guarded by an `asyncio.Semaphore` that caps concurrent
requests at five.
If an API returns an HTTP error or cannot be reached, its dossier section is
marked `Unavailable`; the other sources still appear in the results.
