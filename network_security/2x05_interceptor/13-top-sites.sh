#!/bin/bash
awk '{print $7}' /var/log/squid/access.log | cut -d'/' -f3 | sort | uniq -c | sort -rn | head -10
