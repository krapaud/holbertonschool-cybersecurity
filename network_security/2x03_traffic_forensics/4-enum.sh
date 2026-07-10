#!/bin/bash
tshark -r "$1" -Y "http.response.code == 404" -T fields -e frame.number| wc -l
