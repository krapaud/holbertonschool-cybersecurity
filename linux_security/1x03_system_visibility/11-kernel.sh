#!/bin/bash
grep -s 'segfault' "$1" /var/log/kern.log /var/log/messages
