#!/bin/bash
file="/var/log/auth.log"
echo "File: /var/log/auth.log - Lines: $(wc -l /var/log/auth.log | awk '{print $1}')"

file="/var/log/syslog"
echo "File: /var/log/syslog - Lines: $(wc -l "${file}" | awk '{print $1}')"

file="/var/log/kern.log"
echo "File: /var/log/kern.log - Lines: $(wc -l "${file}" | awk '{print $1}')"
