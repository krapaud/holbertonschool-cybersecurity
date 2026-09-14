#!/bin/bash
awk '{
    for (field = 2; field <= NF; field++) {
        if ($field ~ /^4[0-9][0-9]$/) {
            errors[$1]++
            break
        }
    }
}
END {
    for (ip in errors)
        if (errors[ip] > 5)
            print "ALERT: IP " ip " is scanning us!"
}' "$1"
