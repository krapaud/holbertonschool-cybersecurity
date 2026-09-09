#!/bin/bash
grep "Failed password" "$1" | awk '{
    for (i = 1; i <= NF; i++) {
        if ($i == "from") {
            print $(i + 1)
        }
    }
}' | sort | uniq -c | sort -nr
