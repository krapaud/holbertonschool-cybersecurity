#!/bin/bash
echo "inet 10.10.14.5/23 scope global tun0" | grep "inet" | awk $2 '{print $2}'
