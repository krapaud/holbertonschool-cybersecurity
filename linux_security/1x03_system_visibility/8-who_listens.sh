#!/bin/bash
lsof -iTCP:$1 -sTCP:LISTEN -n -P | awk 'NR>1{print $1}'
