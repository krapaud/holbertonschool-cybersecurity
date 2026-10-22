#!/usr/bin/env python3
"""Provide small timing and port-order helpers for NetProbe."""

import random
import time
from typing import List


def wait_before_scan(delay: float, message: str) -> None:
    """Wait for a requested duration and print the associated debug message.

    Args:
        delay: Number of seconds to wait. Values at or below zero are ignored.
        message: Text to print immediately before waiting.
    """
    if delay > 0:
        print(message)
        time.sleep(delay)


def build_port_order(
    start_port: int,
    end_port: int,
    randomize: bool = False,
) -> List[int]:
    """Build an inclusive port list and optionally shuffle its order.

    Args:
        start_port: First port in the range.
        end_port: Last port in the range.
        randomize: Whether to shuffle the resulting port list.

    Returns:
        Ports from ``start_port`` through ``end_port``, optionally shuffled.
    """
    ports = list(range(start_port, end_port + 1))
    if randomize:
        random.shuffle(ports)
        print("Scanning ports randomly...")
    return ports
