#!/bin/bash
grep -s 'segfault' /var/log/kern.log /var/log/messages
