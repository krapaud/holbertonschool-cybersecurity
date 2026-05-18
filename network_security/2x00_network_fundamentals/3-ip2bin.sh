#!/bin/bash
for octet in $(echo $1 | tr '.' ' '); do
    binary=$(printf "%08d\n" $(echo "obase=2; $octet" | bc))
    if [ -z "$result" ]; then
        result="$binary"
    else
        result="$result.$binary"
    fi
done
echo $result
