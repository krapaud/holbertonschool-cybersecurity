#!/bin/bash
if [ -f /var/log/kern.log ]; then
    grep 'segfault' /var/log/kern.log
fi

if [ -f /var/log/messages ]; then
    grep 'segfault' /var/log/messages
fi
