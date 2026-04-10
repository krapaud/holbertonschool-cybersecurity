#!/bin/bash
ps -eo pid,pcpu,comm --sort=-%cpu | head -n 2 | tail -n 1 | awk '{print $1,$3}'
