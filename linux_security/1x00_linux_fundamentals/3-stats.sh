#!/bin/bash
ls -l $1 | awk 'NR>1 {print $3}' | uniq -c | sort -rn | head -1
