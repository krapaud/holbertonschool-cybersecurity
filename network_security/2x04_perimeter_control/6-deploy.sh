#!/bin/bash
scp skeleton.conf user@$1:/tmp/skeleton.conf ; ssh user@$1 "./2-panic.sh && nft -f /tmp/skeleton.conf && nft list ruleset"
