#!/bin/bash
if [ ! -f sentinel.conf ]; then
    exit 1
else
    source sentinel.conf
fi
if [ -z "$SERVICES" ]; then
    exit 1
fi
if [ -z "$FILES_TO_WATCH" ]; then
    exit 1
fi
