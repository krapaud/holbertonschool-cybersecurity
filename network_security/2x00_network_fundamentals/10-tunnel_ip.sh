#!/bin/bash
ip addr show tun0 | grep "inet" | awk '{print $2}'
