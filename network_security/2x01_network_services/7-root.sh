#!/bin/bash
dig +short +trace $1 | head -n 1 | awk '{print $5}'
