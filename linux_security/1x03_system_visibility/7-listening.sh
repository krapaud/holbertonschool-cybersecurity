#!/bin/bash
ss -lt4 | awk -F':' 'NR>1{print $2}'
