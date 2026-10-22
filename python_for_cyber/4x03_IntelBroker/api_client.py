#!/usr/bin/env python3
"""Asynchronous clients for IntelBroker threat-intelligence APIs."""

import asyncio
from typing import Any, Dict, List

import aiohttp

if __package__:
    from .utils import load_cached_intel, save_cached_intel
else:
    from utils import load_cached_intel, save_cached_intel


API_URLS = {
    "virustotal": "http://localhost:5000/virustotal/{}",
    "shodan": "http://localhost:5000/shodan/{}",
    "abuseipdb": "http://localhost:5000/abuseipdb/{}",
}


async def fetch_api(
    session: aiohttp.ClientSession,
    url: str,
) -> Dict[str, Any]:
    """Fetch JSON or return an Unavailable error without raising API errors."""
    try:
        async with session.get(url) as response:
            if response.status != 200:
                print(f"[ERROR] API returned HTTP {response.status}.")
                return {"error": "Unavailable"}
            payload = await response.json()
    except (aiohttp.ClientError, asyncio.TimeoutError) as error:
        print(f"[ERROR] API request failed: {error}")
        return {"error": "Unavailable"}
    except ValueError:
        print("[ERROR] API response is not valid JSON.")
        return {"error": "Unavailable"}

    if not isinstance(payload, dict):
        print("[ERROR] API response must be a JSON object.")
        return {"error": "Unavailable"}
    return payload


async def _query_api_async(source: str, ip: str) -> Dict[str, Any]:
    """Query one API endpoint using a short-lived async HTTP session."""
    timeout = aiohttp.ClientTimeout(total=5)
    try:
        async with aiohttp.ClientSession(timeout=timeout) as session:
            url = API_URLS[source].format(ip)
            return await fetch_api(session, url)
    except aiohttp.ClientError as error:
        print(f"[ERROR] Cannot connect to the mock API server: {error}")
        return {"error": "Unavailable"}


def _query_api(source: str, ip: str) -> Dict[str, Any]:
    """Run one async API query via the existing synchronous interface."""
    try:
        return asyncio.run(_query_api_async(source, ip))
    except RuntimeError as error:
        print(f"[ERROR] Could not run asynchronous API query: {error}")
        return {"error": "Unavailable"}


def query_virustotal(ip: str) -> Dict[str, Any]:
    """Return VirusTotal mock data for an IP as a dictionary."""
    return _query_api("virustotal", ip)


def query_abuseipdb(ip: str) -> Dict[str, Any]:
    """Return AbuseIPDB mock data including its confidence score."""
    return _query_api("abuseipdb", ip)


async def gather_intel(ip: str) -> List[Dict[str, Any]]:
    """Return cached or concurrently fetched API results for an IP."""
    cached_data = load_cached_intel(ip)
    if cached_data is not None:
        print(f"[INFO] Using cached intelligence for {ip}.")
        return cached_data

    timeout = aiohttp.ClientTimeout(total=5)
    semaphore = asyncio.Semaphore(5)
    async with aiohttp.ClientSession(timeout=timeout) as session:
        urls = [API_URLS[source].format(ip) for source in API_URLS]

        async def fetch_with_limit(url: str) -> Dict[str, Any]:
            """Fetch one source while respecting the shared concurrency cap."""
            async with semaphore:
                return await fetch_api(session, url)

        results = await asyncio.gather(
            *(fetch_with_limit(url) for url in urls)
        )
    if all(result and "error" not in result for result in results):
        save_cached_intel(ip, results)
    return results
