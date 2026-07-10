#!/bin/bash
tshark -r "$1" -Y "urlencoded-form.value" -T fields -e urlencoded-form.key -e urlencoded-form.value | awk '($1 == "password" || $1 == "pass" || $1 == "pwd") {print $2}'
