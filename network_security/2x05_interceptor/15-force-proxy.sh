#!/bin/bash
nft add rule inet filter forward ip saddr 10.200.0.1 tcp dport { 80, 443 } accept
nft add rule inet filter forward ip saddr 10.200.0.0/24 tcp dport { 80, 443 } drop
