#!/bin/bash
file="/var/log/auth.log"
echo "File: ${file} - Lines: $(wc -l "${file}" | awk '{print $1}')"

file="/var/log/syslog"
echo "File: ${file} - Lines: $(wc -l "${file}" | awk '{print $1}')"

file="/var/log/kern.log"
echo "File: ${file} - Lines: $(wc -l "${file}" | awk '{print $1}')"
