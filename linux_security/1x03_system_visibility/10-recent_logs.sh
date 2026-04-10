#!/bin/bash
START=$(date --date="30 minutes ago" +"%H:%M:%S")
awk -v start="$START" '$3 >= start && /sshd/' $1
