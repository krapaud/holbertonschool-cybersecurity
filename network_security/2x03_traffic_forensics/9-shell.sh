#!/bin/bash
tshark -r "$1" -Y 'frame contains "uid=0" || frame contains "root"' -T fields -e tcp.dstport
