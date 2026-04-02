#!/bin/bash
until nc -z -w1 $1 80 &>/dev/null; do
    echo "Waiting..."
    sleep 1
done
echo "Service UP!"
