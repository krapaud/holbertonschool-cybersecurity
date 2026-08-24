#!/bin/bash
tshark -r "$1" -Y 'http.request.uri contains "SELECT" || http.request.uri contains "%53%45%4c%45%43%54" || http.request.uri contains "UNION" || http.request.uri contains "%55%4e%49%4f%4e"' -T fields -e http.request.uri
