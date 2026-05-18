#!/bin/bash
IFS='.' read -ra octets <<< "$1" ; IFS='.' read -ra mask <<< "$2"
printf "%d.%d.%d.%d" $((${octets[0]} & ${mask[0]})) $((${octets[1]} & ${mask[1]})) $((${octets[2]} & ${mask[2]})) $((${octets[3]} & ${mask[3]}))