#!/bin/bash
if squid -k parse; then squid -k reconfigure; else echo "Error"; exit 1; fi
