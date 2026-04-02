#!/bin/bash
while read ligne; do
    if id "$ligne" &>/dev/null; then
        usermod -L $ligne
        echo "User $ligne locked"
    else 
        echo "User $ligne not found"
    fi
done < $1
