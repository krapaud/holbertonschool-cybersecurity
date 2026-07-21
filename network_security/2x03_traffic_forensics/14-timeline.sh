#!/bin/bash
tshark -r "$1" -Y 'ip.addr' -T fields -e frame.time | awk 'NR==1{first=$0} END{print first; print $0}'
