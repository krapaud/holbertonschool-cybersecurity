#!/bin/bash
tshark -r "$1" -Y "http" -T fields -e http.user_agent | sort | uniq
