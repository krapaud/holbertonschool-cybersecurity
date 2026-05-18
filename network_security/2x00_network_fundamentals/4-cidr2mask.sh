#!/bin/bash
binary="$(printf '%.0s1' $(seq 1 $1))$(printf '%.0s0' $(seq 1 $((32 - $1))))"
printf "%d.%d.%d.%d\n" $(echo "ibase=2; ${binary:0:8}" | bc) $(echo "ibase=2; ${binary:8:8}" | bc) $(echo "ibase=2; ${binary:16:8}" | bc) $(echo "ibase=2; ${binary:24:8}" | bc)
