#!/bin/bash
awk -F: '$3 < 1000 && $7 ~ $7 ~ /(sh|bash)$/ && $1 != "root" {print $1}' $1
