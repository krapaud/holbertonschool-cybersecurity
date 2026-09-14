#!/bin/bash

awk '{
    for (field = 2; field <= NF; field++) {
        if ($field ~ /^4[0-9][0-9]$/) {
            print $1
            break
        }
    }
}' "$1" | sort | uniq -c | while read -r count ip
do
    if [ "$count" -gt 5 ]
    then
        echo "ALERT: IP $ip is scanning us!"
    fi
done
