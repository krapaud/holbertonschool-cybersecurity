#!/bin/bash
grep -s "$1" /var/log/kern.log /var/log/messages
