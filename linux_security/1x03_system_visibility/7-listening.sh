#!/bin/bash
ss -lt4 | awk 'NR>1{split($4,a,":"); print a[2]}'
