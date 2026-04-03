#!/bin/bash
if grep -qE "^#?PermitRootLogin" $1; then
    sed -i -E 's/^#?PermitRootLogin .*/PermitRootLogin no/' $1
else
    echo "PermitRootLogin no" >> $1
fi
if grep -qE "^#?PasswordAuthentication" $1; then
    sed -i -E 's/^#?PasswordAuthentication .*/PasswordAuthentication no/' $1
else
    echo "PasswordAuthentication no" >> $1
fi
if grep -qE "^#?PubkeyAuthentication" $1; then
    sed -i -E 's/^#?PubkeyAuthentication .*/PubkeyAuthentication yes/' $1
else
    echo "PubkeyAuthentication yes" >> $1
fi
if sshd -t -f $1; then
    systemctl reload sshd
fi
