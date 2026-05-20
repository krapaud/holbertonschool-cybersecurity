#!/bin/bash
cat /etc/hosts | grep "localhost" | grep "127" | awk '{printf $1}'
