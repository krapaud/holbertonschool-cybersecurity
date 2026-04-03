#!/bin/bash
awk -F: '$3 >= 1000 {print $1}' $1 | while read user; do
    awk -v u="$user" -F: '$1 ~ /^(docker|disk|shadow)$/ && $4 ~ u {print u ":" $1}' /etc/group
done
